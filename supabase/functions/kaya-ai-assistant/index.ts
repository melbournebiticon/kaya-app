// =============================================================================
// KAYA Phase 9 — Secure Server-Side AI Assistant Edge Function (Supabase/Deno)
// =============================================================================
// Security Rules (README Section 3 Phase 9 & Section 7):
// 1. Private AI API key (`GEMINI_API_KEY`) lives strictly in server secrets.
// 2. Requires a valid Supabase user JWT (`Authorization: Bearer <token>`).
// 3. Enforces per-user daily request cap and strict maxOutputTokens cost limit.
// 4. Accepts only minimized context payloads and returns structured JSON.
// 5. Never mutates user records directly; task suggestions require client confirmation.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MAX_DAILY_REQUESTS = 25;
const MAX_PROMPT_LENGTH = 300;
const MAX_OUTPUT_TOKENS = 512;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "Authentication required." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey || !geminiApiKey) {
      return jsonResponse(
        { error: "AI backend is not configured on the server." },
        503,
      );
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData?.user) {
      return jsonResponse({ error: "Invalid or expired session." }, 401);
    }
    const userId = authData.user.id;

    const payload = await req.json();
    const prompt = typeof payload?.prompt === "string"
      ? payload.prompt.trim()
      : "";
    if (!prompt || prompt.length > MAX_PROMPT_LENGTH) {
      return jsonResponse(
        { error: `Prompt must be between 1 and ${MAX_PROMPT_LENGTH} characters.` },
        400,
      );
    }

    // Enforce per-user daily usage quota via RLS-protected ai_usage_daily.
    const todayIso = new Date().toISOString().slice(0, 10);
    const { data: usageRow } = await supabase
      .from("ai_usage_daily")
      .select("request_count, estimated_tokens")
      .eq("user_id", userId)
      .eq("usage_date", todayIso)
      .maybeSingle();

    const currentCount = Number(usageRow?.request_count ?? 0);
    const currentTokens = Number(usageRow?.estimated_tokens ?? 0);
    if (currentCount >= MAX_DAILY_REQUESTS) {
      return jsonResponse(
        {
          error: "Daily AI usage limit reached.",
          code: "QUOTA_EXCEEDED",
          usedToday: currentCount,
          dailyLimit: MAX_DAILY_REQUESTS,
        },
        429,
      );
    }

    const language = payload?.language === "taglish" ? "Taglish" : "English";
    const minimizedContext = payload?.minimizedContext ?? {};
    const recentHistory = Array.isArray(payload?.recentHistory)
      ? payload.recentHistory.slice(-4)
      : [];

    const systemInstruction = [
      "You are KAYA Assistant, a calm, concise personal life-management assistant.",
      `Respond in ${language}.`,
      "Use ONLY the minimized user context provided. Never invent tasks, bills, amounts, or dates.",
      "Never claim to have modified or saved any database record.",
      "You may propose up to 3 actionable tasks in `suggestedTasks` when the user asks for planning or task breakdown.",
      "Return strictly valid JSON with keys: `replyText` (string), `details` (string[]), `suggestedTasks` ({title, priority, category, dueDate}[]).",
    ].join(" ");

    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${
        encodeURIComponent(geminiApiKey)
      }`;

    const aiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemInstruction }] },
        contents: [
          {
            role: "user",
            parts: [
              {
                text: JSON.stringify({
                  prompt,
                  minimizedContext,
                  recentHistory,
                }),
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          maxOutputTokens: MAX_OUTPUT_TOKENS,
          temperature: 0.3,
        },
      }),
    });

    if (!aiResponse.ok) {
      return jsonResponse({ error: "AI provider request failed." }, 502);
    }

    const aiJson = await aiResponse.json();
    const rawText = aiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const parsed = JSON.parse(rawText);
    const totalTokens = Number(aiJson?.usageMetadata?.totalTokenCount ?? 250);

    await supabase.from("ai_usage_daily").upsert(
      {
        user_id: userId,
        usage_date: todayIso,
        request_count: currentCount + 1,
        estimated_tokens: currentTokens + totalTokens,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id,usage_date" },
    );

    return jsonResponse({
      replyText: typeof parsed?.replyText === "string" ? parsed.replyText : "",
      details: Array.isArray(parsed?.details) ? parsed.details : [],
      suggestedTasks: Array.isArray(parsed?.suggestedTasks)
        ? parsed.suggestedTasks
        : [],
      estimatedTokens: totalTokens,
      providerLabel: "KAYA Cloud AI",
    });
  } catch {
    return jsonResponse(
      { error: "Unable to process AI request safely." },
      500,
    );
  }
});
