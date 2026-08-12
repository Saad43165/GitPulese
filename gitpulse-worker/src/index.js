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

    // Privacy Policy for Google Play Store compliance
    if (url.pathname === '/privacy') {
      const html = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Privacy Policy - GitPulse</title>
          <style>body { font-family: sans-serif; max-width: 800px; margin: 40px auto; line-height: 1.6; padding: 0 20px; color: #333; }</style>
        </head>
        <body>
          <h1>Privacy Policy for GitPulse</h1>
          <p><strong>Last Updated: August 2026</strong></p>
          <p>GitPulse ("we", "our", or "us") respects your privacy. This Privacy Policy explains how we handle your data when you use the GitPulse mobile application.</p>
          <h2>1. Data We Collect</h2>
          <p>GitPulse acts as a client for GitHub. When you log in, we authenticate directly with GitHub using OAuth. We receive an access token that is stored <strong>locally and securely</strong> on your device using encrypted storage. We do not transmit this token to any third-party servers, nor do we store it in a central database.</p>
          <h2>2. How We Use Your Data</h2>
          <p>Your GitHub data (repositories, profile, pull requests, etc.) is accessed strictly to display it within the app. We do not sell, rent, or share your personal data or GitHub source code with third parties.</p>
          <h2>3. AI Features</h2>
          <p>If you use our AI features (like PR Summaries or Code Explanations), snippets of code and metadata you explicitly choose to analyze are sent to our secure AI provider (Groq/Cloudflare). This data is used solely to generate the response and is not used to train models or stored persistently.</p>
          <h2>4. Your Rights</h2>
          <p>You can revoke GitPulse's access to your GitHub account at any time by visiting your GitHub Settings (Applications -> Authorized OAuth Apps) and revoking access. You can also delete the app, which instantly removes all locally stored tokens and preferences.</p>
          <h2>5. Contact Us</h2>
          <p>If you have any questions about this Privacy Policy, please contact the developer via the app's GitHub repository or Play Store listing.</p>
        </body>
        </html>
      `;
      return new Response(html, { headers: { 'Content-Type': 'text/html;charset=UTF-8' } });
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

    // GitHub OAuth token exchange — must be before Groq key check
    if (url.pathname === '/auth/github/token') {
      return await handleGitHubOAuth(body, env);
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

async function handleGitHubOAuth(body, env) {
  const { code } = body;
  if (!code) return json({ error: 'Missing code' }, 400);

  const clientSecret = env.GITHUB_CLIENT_SECRET;
  if (!clientSecret) return json({ error: 'GITHUB_CLIENT_SECRET not configured' }, 500);

  const resp = await fetch('https://github.com/login/oauth/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({
      client_id: 'Ov23liSRrNr1PE6Kbd1F',
      client_secret: clientSecret,
      code,
    }),
  });

  if (!resp.ok) {
    return json({ error: `GitHub token exchange failed: ${resp.status}` }, 502);
  }

  const data = await resp.json();
  if (data.error) return json({ error: data.error_description || data.error }, 400);
  return json({ access_token: data.access_token, token_type: data.token_type, scope: data.scope });
}

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
