/**
 * AviQuest Users API Lambda Handler
 *
 * Routes:
 *   GET  /users/profile     — Get authenticated user's profile
 *   GET  /users/collection   — Get user's bird collection
 *   POST /users/collection   — Add a bird to user's collection
 *   GET  /leaderboard        — Get top players by XP
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
  QueryCommand,
  ScanCommand,
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const dynamo = DynamoDBDocumentClient.from(client);

const USERS_TABLE = process.env.USERS_TABLE;
const BIRDS_TABLE = process.env.BIRDS_TABLE;

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
};

exports.handler = async (event) => {
  const { routeKey, pathParameters, queryStringParameters, body } = event;
  const params = queryStringParameters || {};
  const userId = event.requestContext?.authorizer?.jwt?.claims?.sub;

  try {
    switch (routeKey) {
      case "GET /users/profile":
        return await getProfile(userId);
      case "GET /users/collection":
        return await getCollection(userId, params);
      case "POST /users/collection":
        return await addToCollection(userId, JSON.parse(body));
      case "GET /leaderboard":
        return await getLeaderboard(params);
      default:
        return response(404, { error: "Not found" });
    }
  } catch (err) {
    console.error("Handler error:", err);
    return response(500, { error: "Internal server error" });
  }
};

async function getProfile(userId) {
  if (!userId) return response(401, { error: "Unauthorized" });

  const result = await dynamo.send(
    new GetCommand({
      TableName: USERS_TABLE,
      Key: { user_id: userId },
    })
  );

  if (!result.Item) {
    // Create new profile for first-time users
    const newProfile = {
      user_id: userId,
      username: `Birder_${userId.slice(0, 8)}`,
      total_xp: 0,
      level: 1,
      collection_count: 0,
      created_at: new Date().toISOString(),
    };

    await dynamo.send(
      new PutCommand({
        TableName: USERS_TABLE,
        Item: newProfile,
      })
    );

    return response(200, { profile: newProfile });
  }

  return response(200, { profile: result.Item });
}

async function getCollection(userId, params) {
  if (!userId) return response(401, { error: "Unauthorized" });

  const limit = Math.min(parseInt(params.limit) || 50, 100);
  const result = await dynamo.send(
    new QueryCommand({
      TableName: `${USERS_TABLE.replace("users", "collections")}`,
      KeyConditionExpression: "user_id = :uid",
      ExpressionAttributeValues: { ":uid": userId },
      Limit: limit,
    })
  );

  return response(200, {
    collection: result.Items,
    count: result.Items.length,
  });
}

async function addToCollection(userId, body) {
  if (!userId) return response(401, { error: "Unauthorized" });

  const { bird_id } = body;
  if (!bird_id) {
    return response(400, { error: "bird_id is required" });
  }

  // Verify bird exists
  const birdResult = await dynamo.send(
    new GetCommand({
      TableName: BIRDS_TABLE,
      Key: { bird_id },
    })
  );

  if (!birdResult.Item) {
    return response(404, { error: "Bird not found" });
  }

  const bird = birdResult.Item;
  const xpEarned = calculateXp(bird.base_xp, bird.rarity);

  // Add to collection
  const collectionTable = USERS_TABLE.replace("users", "collections");
  await dynamo.send(
    new PutCommand({
      TableName: collectionTable,
      Item: {
        user_id: userId,
        bird_id,
        found_at: new Date().toISOString(),
        xp_earned: xpEarned,
      },
      ConditionExpression:
        "attribute_not_exists(user_id) AND attribute_not_exists(bird_id)",
    })
  );

  // Update user XP and collection count
  await dynamo.send(
    new UpdateCommand({
      TableName: USERS_TABLE,
      Key: { user_id: userId },
      UpdateExpression:
        "SET total_xp = total_xp + :xp, collection_count = collection_count + :one, #lvl = :level",
      ExpressionAttributeNames: { "#lvl": "level" },
      ExpressionAttributeValues: {
        ":xp": xpEarned,
        ":one": 1,
        ":level": 1, // will be recalculated client-side based on total_xp
      },
    })
  );

  return response(201, {
    message: "Bird added to collection",
    bird_id,
    xp_earned: xpEarned,
  });
}

async function getLeaderboard(params) {
  const limit = Math.min(parseInt(params.limit) || 20, 50);

  // Scan and sort (for small-scale; use GSI for production scale)
  const result = await dynamo.send(
    new ScanCommand({
      TableName: USERS_TABLE,
      ProjectionExpression:
        "user_id, username, total_xp, #lvl, collection_count",
      ExpressionAttributeNames: { "#lvl": "level" },
      Limit: 200,
    })
  );

  const sorted = result.Items.sort((a, b) => b.total_xp - a.total_xp).slice(
    0,
    limit
  );

  return response(200, { leaderboard: sorted, count: sorted.length });
}

function calculateXp(baseXp, rarity) {
  const multipliers = {
    common: 1,
    uncommon: 1.5,
    rare: 2,
    legendary: 5,
  };
  return Math.round((baseXp || 50) * (multipliers[rarity] || 1));
}

function response(statusCode, body) {
  return { statusCode, headers, body: JSON.stringify(body) };
}
