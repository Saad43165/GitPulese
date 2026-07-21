/**
 * GitPulse AI Backend — Cloudflare Worker
 * 
 * DEPLOY INSTRUCTIONS (takes ~5 minutes):
 * =========================================
 * 1. npm install -g wrangler
 * 2. wrangler login
 * 3. wrangler deploy
 * 4. wrangler secret put GROQ_API_KEY
 *    → paste your Groq key (gsk_...) when prompted
 * 
 * Your Worker URL will be: https://gitpulse-ai.<your-subdomain>.workers.dev
 * Paste that URL into lib/core/constants/api_constants.dart → backendBaseUrl
 * 
 * FREE TIER: 100,000 requests/day, zero cold starts, global edge network.
 * Get your free Groq key at: https://console.groq.com
 */

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = 'llama-3.1-8b-instant';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // Health check endpoint
    if (url.pathname === '/health' || url.pathname === '/') {
      return json({ status: 'ok', service: 'GitPulse AI Worker' });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    const groqKey = env.GROQ_API_KEY;
    if (!groqKey) {
      return json({ error: 'GROQ_API_KEY secret not configured on Worker' }, 500);
    }

    try {
      if (url.pathname === '/ai/summarize') {
        return await handleSummarize(body, groqKey);
      }
      if (url.pathname === '/ai/explain-code') {
        return await handleExplainCode(body, groqKey);
      }
      if (url.pathname === '/ai/analyze-user') {
        return await handleAnalyzeUser(body, groqKey);
      }
      return json({ error: 'Unknown route' }, 404);
    } catch (e) {
      return json({ error: e.message || 'Internal error' }, 500);
    }
  },
};

// ── Route Handlers ────────────────────────────────────────────────────────────

async function handleSummarize(body, groqKey) {
  const { repoFullName, description, readme, primaryLanguage, topics } = body;
  const prompt = `You are an expert developer assistant. Summarize the following GitHub repository in 3–4 concise paragraphs covering its purpose, tech stack, key features, and who would benefit from it.

Repository: ${repoFullName}
Language: ${primaryLanguage || 'Unknown'}
Topics: ${(topics || []).join(', ')}
Description: ${description || 'None'}
README excerpt:
${readme ? readme.substring(0, 2000) : 'No README available'}`;

  const summary = await callGroq(groqKey, 'You are a senior software engineer who writes clear, insightful repository summaries.', prompt);
  return json({ summary });
}

async function handleExplainCode(body, groqKey) {
  const { filename, code } = body;
  const explanation = await callGroq(
    groqKey,
    'You are an expert code reviewer. Provide clear, structured, and actionable analysis.',
    `File: ${filename}\n\n${code}`
  );
  return json({ explanation });
}

async function handleAnalyzeUser(body, groqKey) {
  const { username, bio, repos } = body;
  const repoList = (repos || [])
    .map(r => `- ${r.name} (${r.language || 'unknown'}, ⭐${r.stars}): ${r.description || 'No description'}`)
    .join('\n');

  const prompt = `Analyze the GitHub profile of developer "@${username}".
Bio: ${bio || 'None'}
Repositories:
${repoList}

Write a 2–3 paragraph developer profile covering their primary domain, coding style, technology preferences, and standout projects.`;

  const analysis = await callGroq(
    groqKey,
    'You are a senior engineering recruiter who writes insightful developer profiles based on GitHub activity.',
    prompt
  );
  return json({ analysis });
}

// ── Groq Client ───────────────────────────────────────────────────────────────

async function callGroq(apiKey, systemPrompt, userContent) {
  const response = await fetch(GROQ_API_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
      temperature: 0.4,
      max_tokens: 2048,
    }),
  });

  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    const msg = err?.error?.message || `Groq API error ${response.status}`;
    throw new Error(msg);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content || content.trim() === '') {
    throw new Error('Groq returned an empty response.');
  }
  return content.trim();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: CORS_HEADERS,
  });
}
