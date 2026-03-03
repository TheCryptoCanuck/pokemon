/**
 * AviQuest Birds API Lambda Handler
 *
 * Routes:
 *   GET /birds              — List all birds (paginated)
 *   GET /birds/{bird_id}    — Get a single bird by ID
 *   GET /birds/rarity/{rarity} — Filter birds by rarity tier
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  ScanCommand,
  GetCommand,
  QueryCommand,
} = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const dynamo = DynamoDBDocumentClient.from(client);

const TABLE = process.env.BIRDS_TABLE;

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
};

exports.handler = async (event) => {
  const { routeKey, pathParameters, queryStringParameters } = event;
  const params = queryStringParameters || {};

  try {
    switch (routeKey) {
      case "GET /birds":
        return await listBirds(params);
      case "GET /birds/{bird_id}":
        return await getBird(pathParameters.bird_id);
      case "GET /birds/rarity/{rarity}":
        return await getBirdsByRarity(pathParameters.rarity, params);
      default:
        return response(404, { error: "Not found" });
    }
  } catch (err) {
    console.error("Handler error:", err);
    return response(500, { error: "Internal server error" });
  }
};

async function listBirds(params) {
  const limit = Math.min(parseInt(params.limit) || 50, 100);
  const command = new ScanCommand({
    TableName: TABLE,
    Limit: limit,
    ExclusiveStartKey: params.cursor
      ? JSON.parse(Buffer.from(params.cursor, "base64url").toString())
      : undefined,
  });

  const result = await dynamo.send(command);

  return response(200, {
    birds: result.Items,
    count: result.Items.length,
    cursor: result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString(
          "base64url"
        )
      : null,
  });
}

async function getBird(birdId) {
  const result = await dynamo.send(
    new GetCommand({
      TableName: TABLE,
      Key: { bird_id: birdId },
    })
  );

  if (!result.Item) {
    return response(404, { error: "Bird not found" });
  }

  return response(200, { bird: result.Item });
}

async function getBirdsByRarity(rarity, params) {
  const validRarities = ["common", "uncommon", "rare", "legendary"];
  if (!validRarities.includes(rarity)) {
    return response(400, {
      error: `Invalid rarity. Must be one of: ${validRarities.join(", ")}`,
    });
  }

  const limit = Math.min(parseInt(params.limit) || 50, 100);
  const result = await dynamo.send(
    new QueryCommand({
      TableName: TABLE,
      IndexName: "rarity-index",
      KeyConditionExpression: "rarity = :rarity",
      ExpressionAttributeValues: { ":rarity": rarity },
      Limit: limit,
    })
  );

  return response(200, {
    birds: result.Items,
    count: result.Items.length,
    rarity,
  });
}

function response(statusCode, body) {
  return { statusCode, headers, body: JSON.stringify(body) };
}
