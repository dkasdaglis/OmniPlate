import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { imageBase64 } = await req.json();

    if (!imageBase64) {
      throw new Error('No image provided');
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      throw new Error("API Key is missing in Edge Function secrets.");
    }

    const prompt = "Analyze this meal. Provide the estimated Name, Calories, Protein (g), Carbs (g), and Fats (g) in a strict JSON format with keys: name, calories, protein, carbs, fats. No markdown, just JSON.";

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
            ]
          }]
        })
      }
    );

    const data = await response.json();

    // 🚨 ΤΟ ΡΑΝΤΑΡ: Αν η Google βγάλει error, να μας το πει ξεκάθαρα στο app!
    if (data.error) {
      throw new Error(`Google API Error: ${data.error.message}`);
    }

    const textResult = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!textResult) {
      throw new Error(`Unexpected Google Response: ${JSON.stringify(data)}`);
    }

    return new Response(JSON.stringify({ result: textResult }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
})