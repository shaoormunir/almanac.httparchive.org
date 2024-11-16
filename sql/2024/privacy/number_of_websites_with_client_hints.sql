#standardSQL
# Pages that use Client Hints
WITH
  response_headers AS (
  SELECT
    r.client,
    r.page,
    p.rank,
    header.name header_name,
    header.value header_value
  FROM
    `httparchive.all.requests`  r,
    UNNEST(r.response_headers) header
  JOIN
    `httparchive.all.pages` p
  ON
    r.date = p.date
    AND r.client = p.client
    AND r.page = p.page
    AND r.is_root_page = p.is_root_page
  WHERE
    r.date = '2024-06-01'
    AND is_main_document = TRUE ),

  meta_tags AS (
  SELECT
    client,
    page,
    LOWER(JSON_VALUE(meta_node, '$.http-equiv')) AS tag_name,
    LOWER(JSON_VALUE(meta_node, '$.content')) AS tag_value
  FROM (
    SELECT
      client,
      page,
      JSON_VALUE(payload, '$._almanac') AS metrics
    FROM
      `httparchive.all.pages`
    WHERE
    date = '2024-06-01'
    ),
    UNNEST(JSON_QUERY_ARRAY(metrics, '$.meta-nodes.nodes')) meta_node
  WHERE
    JSON_VALUE(meta_node, '$.http-equiv') IS NOT NULL
),

totals AS (
  SELECT
    r.client,
    rank_grouping,
    COUNT(DISTINCT r.page) AS total_websites
  FROM
    `httparchive.all.requests` r,
    UNNEST([1000, 10000, 100000, 1000000, 10000000]) AS rank_grouping
    JOIN
    `httparchive.all.pages` p
  ON
    r.date = p.date
    AND r.client = p.client
    AND r.page = p.page
    AND r.is_root_page = p.is_root_page
  WHERE
    r.date = '2024-06-01' AND
    is_main_document = TRUE AND
    rank <= rank_grouping
  GROUP BY
    client,
    rank_grouping
)


SELECT
  client,
  rank_grouping,
  COUNT(DISTINCT page) AS number_of_websites,
  COUNT(DISTINCT page) / total_websites AS pct_websites
FROM
  response_headers
FULL OUTER JOIN
  meta_tags
USING (client, page),
  UNNEST([1000, 10000, 100000, 1000000, 10000000]) AS rank_grouping
JOIN
  totals
USING (client, rank_grouping)
WHERE
  (
    header_name = 'accept-ch' OR
    tag_name = 'accept-ch'
  ) AND
  rank <= rank_grouping
GROUP BY
  client,
  rank_grouping,
  total_websites
ORDER BY
  rank_grouping,
  client
