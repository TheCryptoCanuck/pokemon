import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

interface WebhookPayload {
  type: string;
  record: {
    id: string;
    user_id: string;
    breed: string;
    dog_name: string;
    status: string;
    lat: number;
    lon: number;
    alert_radius_miles: number;
  };
}

interface DeviceToken {
  token: string;
  last_seen_lat: number;
  last_seen_lon: number;
}

interface ServiceAccountKey {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
}

// Haversine distance calculation in km
function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Simple JWT generation for FCM auth
async function generateFCMAccessToken(
  serviceAccountKey: ServiceAccountKey
): Promise<string> {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccountKey.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const headerEncoded = btoa(JSON.stringify(header));
  const payloadEncoded = btoa(JSON.stringify(payload));
  const signatureInput = `${headerEncoded}.${payloadEncoded}`;

  // Sign using Deno's crypto
  const encoder = new TextEncoder();
  const keyData = await crypto.subtle.importKey(
    "pkcs8",
    Deno.core.ops.op_decode_base64(
      serviceAccountKey.private_key
        .replace(/-----BEGIN PRIVATE KEY-----/g, "")
        .replace(/-----END PRIVATE KEY-----/g, "")
        .replace(/\n/g, "")
    ),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    keyData,
    encoder.encode(signatureInput)
  );

  const signatureEncoded = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  const jwt = `${signatureInput}.${signatureEncoded}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }).toString(),
  });

  if (!tokenResponse.ok) {
    throw new Error(
      `FCM token exchange failed: ${tokenResponse.statusText}`
    );
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// Send FCM notification to a single token
async function sendFCMNotification(
  token: string,
  reportId: string,
  breed: string,
  dogName: string,
  projectId: string,
  accessToken: string
): Promise<void> {
  const message = {
    message: {
      token,
      notification: {
        title: "Lost Dog Nearby",
        body: `A ${breed} named ${dogName} was reported missing near you. Keep an eye out!`,
      },
      data: {
        type: "lost_dog_alert",
        report_id: reportId,
      },
      android: {
        priority: "high",
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    }
  );

  if (!response.ok) {
    // Log but don't fail — FCM tokens expire; batch shouldn't fail for individual token issues
    console.warn(
      `FCM send failed for token (last 4: ${token.slice(-4)}): ${response.statusText}`
    );
  } else {
    console.log(`FCM notification sent to token (last 4: ${token.slice(-4)})`);
  }
}

serve(async (req) => {
  try {
    // Validate webhook origin (optional but recommended)
    // You can add Supabase webhook signature validation here if needed

    const payload: WebhookPayload = await req.json();

    // Only process INSERT events with active status
    if (payload.type !== "INSERT" || payload.record.status !== "active") {
      return new Response(JSON.stringify({ message: "Ignored" }), {
        status: 200,
      });
    }

    const report = payload.record;

    // Validate location data
    if (!report.lat || !report.lon || !report.alert_radius_miles) {
      return new Response(JSON.stringify({ error: "Invalid location data" }), {
        status: 400,
      });
    }

    // Get FCM credentials from environment
    const projectId = Deno.env.get("FCM_PROJECT_ID");
    const serviceAccountKeyJson = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");

    if (!projectId || !serviceAccountKeyJson) {
      return new Response(
        JSON.stringify({ error: "FCM credentials not configured" }),
        { status: 500 }
      );
    }

    const serviceAccountKey: ServiceAccountKey = JSON.parse(serviceAccountKeyJson);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Supabase credentials not configured" }),
        { status: 500 }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch all device tokens with location data (excluding the report owner)
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("token, last_seen_lat, last_seen_lon")
      .neq("user_id", report.user_id)
      .not("last_seen_lat", "is", null)
      .not("last_seen_lon", "is", null);

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500 }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log("No device tokens found for lost dog alert");
      return new Response(
        JSON.stringify({ message: "No tokens to notify" }),
        { status: 200 }
      );
    }

    // Generate FCM access token
    const accessToken = await generateFCMAccessToken(serviceAccountKey);

    // Convert alert radius to km and filter tokens within radius
    const radiusKm = report.alert_radius_miles * 1.60934;
    const targetTokens: DeviceToken[] = [];

    for (const token of tokens) {
      const distance = haversineKm(
        report.lat,
        report.lon,
        token.last_seen_lat!,
        token.last_seen_lon!
      );

      if (distance <= radiusKm) {
        targetTokens.push(token);
      }
    }

    console.log(
      `Sending lost dog alert to ${targetTokens.length} users within ${report.alert_radius_miles} miles`
    );

    // Send FCM notifications in parallel (with error handling per token)
    const sendPromises = targetTokens.map((tokenData) =>
      sendFCMNotification(
        tokenData.token,
        report.id,
        report.breed,
        report.dog_name,
        projectId,
        accessToken
      ).catch((err) => {
        console.error(`Error sending notification to token: ${err.message}`);
        // Don't rethrow — batch should continue even if individual sends fail
      })
    );

    await Promise.all(sendPromises);

    return new Response(
      JSON.stringify({
        message: `Lost dog alert sent to ${targetTokens.length} users`,
      }),
      { status: 200 }
    );
  } catch (error) {
    console.error("Webhook handler error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500 }
    );
  }
});
