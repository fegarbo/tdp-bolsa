-- =============================================================================
-- DQL — Sistema de Gestão de Bolsa de Valores
-- PostgreSQL 13+
-- Autor: Fernando Garbo | Data: 2026-05-17
-- =============================================================================
-- Conteúdo:
--   1. Carteira consolidada por investidor (posição atual + valor de mercado)
--   2. Patrimônio total por investidor
--   3. Histórico de cotações com variação diária
--   4. Capitalização de mercado por empresa (via vw_valor_mercado)
--   5. Histórico de negociações por investidor
--   6. Reconciliação: SUM(movimentações) = saldo_carteira
--   7. Auditoria SCD Type 2 — histórico completo de mudanças em dados mestres
--   8. Point-in-time — estado dos dados em uma data passada
-- =============================================================================


-- =============================================================================
-- 1. CARTEIRA CONSOLIDADA
-- Posição atual por investidor: quantidade, cotação corrente e valor da posição.
-- =============================================================================

SELECT
    i.nome                              AS investidor,
    a.ticker,
    a.tipo                              AS tipo_acao,
    sc.quantidade,
    c.valor                             AS cotacao_atual,
    sc.quantidade * c.valor             AS valor_posicao,
    sc.data_atualizacao                 AS ultima_movimentacao
FROM  saldo_carteira sc
JOIN  investidor i ON i.investidor_id = sc.investidor_id
JOIN  acao       a ON a.acao_id       = sc.acao_id
JOIN  cotacao    c ON c.acao_id       = a.acao_id
WHERE sc.quantidade > 0
  AND c.data_hora = (
      SELECT MAX(c2.data_hora)
      FROM   cotacao c2
      WHERE  c2.acao_id = a.acao_id
  )
ORDER BY i.nome, a.ticker;


-- =============================================================================
-- 2. PATRIMÔNIO TOTAL POR INVESTIDOR
-- Soma do valor de mercado de todas as posições por investidor.
-- =============================================================================

SELECT
    i.nome                              AS investidor,
    COUNT(DISTINCT sc.acao_id)          AS acoes_distintas,
    SUM(sc.quantidade * c.valor)        AS patrimonio_total
FROM  saldo_carteira sc
JOIN  investidor i ON i.investidor_id = sc.investidor_id
JOIN  acao       a ON a.acao_id       = sc.acao_id
JOIN  cotacao    c ON c.acao_id       = a.acao_id
WHERE sc.quantidade > 0
  AND c.data_hora = (
      SELECT MAX(c2.data_hora)
      FROM   cotacao c2
      WHERE  c2.acao_id = a.acao_id
  )
GROUP BY i.investidor_id, i.nome
ORDER BY patrimonio_total DESC;


-- =============================================================================
-- 3. HISTÓRICO DE COTAÇÕES COM VARIAÇÃO DIÁRIA
-- Série temporal por ação com variação absoluta e percentual (window function).
-- =============================================================================

SELECT
    a.ticker,
    c.data_hora,
    c.valor,
    c.valor - LAG(c.valor) OVER (PARTITION BY a.acao_id ORDER BY c.data_hora)  AS variacao,
    ROUND(
        (c.valor - LAG(c.valor) OVER (PARTITION BY a.acao_id ORDER BY c.data_hora))
        / LAG(c.valor) OVER (PARTITION BY a.acao_id ORDER BY c.data_hora) * 100,
        2
    )                                                                           AS variacao_pct
FROM  cotacao c
JOIN  acao    a ON a.acao_id = c.acao_id
ORDER BY a.ticker, c.data_hora;


-- =============================================================================
-- 4. CAPITALIZAÇÃO DE MERCADO POR EMPRESA
-- Usa a VIEW vw_valor_mercado (total_acoes × cotação mais recente).
-- =============================================================================

SELECT
    empresa,
    ticker,
    total_acoes,
    cotacao_atual,
    valor_mercado,
    data_cotacao
FROM  vw_valor_mercado
ORDER BY valor_mercado DESC;


-- =============================================================================
-- 5. HISTÓRICO DE NEGOCIAÇÕES POR INVESTIDOR
-- Registro imutável de todas as operações com valor total derivado.
-- =============================================================================

SELECT
    i.nome                              AS investidor,
    a.ticker,
    n.tipo_operacao,
    n.quantidade,
    n.valor_unitario,
    n.quantidade * n.valor_unitario     AS valor_total,
    n.data_hora_transacao
FROM  negociacao n
JOIN  investidor i ON i.investidor_id = n.investidor_id
JOIN  acao       a ON a.acao_id       = n.acao_id
ORDER BY n.data_hora_transacao, i.nome;


-- =============================================================================
-- 6. RECONCILIAÇÃO DE SALDO
-- Verifica: SUM(compras) - SUM(vendas) = saldo_carteira para cada par
-- (investidor, acao). reconciliado = TRUE confirma integridade dos dados.
-- =============================================================================

SELECT
    i.nome                                      AS investidor,
    a.ticker,
    SUM(CASE n.tipo_operacao
            WHEN 'C' THEN  n.quantidade
            WHEN 'V' THEN -n.quantidade
        END)                                    AS saldo_calculado,
    sc.quantidade                               AS saldo_carteira,
    SUM(CASE n.tipo_operacao
            WHEN 'C' THEN  n.quantidade
            WHEN 'V' THEN -n.quantidade
        END) = sc.quantidade                    AS reconciliado
FROM  negociacao     n
JOIN  investidor     i  ON i.investidor_id  = n.investidor_id
JOIN  acao           a  ON a.acao_id        = n.acao_id
JOIN  saldo_carteira sc ON sc.investidor_id = n.investidor_id
                       AND sc.acao_id       = n.acao_id
GROUP BY i.investidor_id, i.nome, a.acao_id, a.ticker, sc.quantidade
ORDER BY i.nome, a.ticker;


-- =============================================================================
-- 7. AUDITORIA SCD TYPE 2 — HISTÓRICO COMPLETO DE MUDANÇAS
-- Exibe todas as versões de um dado mestre: registros históricos + estado atual.
-- =============================================================================

-- 7a. Histórico de mudanças de setor da Petrobras
SELECT
    cnpj,
    nome,
    setor,
    data_inicio                 AS vigente_de,
    data_fim                    AS vigente_ate,
    'historico'                 AS versao
FROM  empresa_historico
WHERE cnpj = '33000167000101'

UNION ALL

SELECT
    cnpj,
    nome,
    setor,
    data_atualizacao            AS vigente_de,
    NULL                        AS vigente_ate,
    'atual'                     AS versao
FROM  empresa
WHERE cnpj = '33000167000101'

ORDER BY vigente_de;


-- 7b. Histórico de mudanças de nome do investidor Fernando
SELECT
    cpf_cnpj,
    nome,
    data_inicio                 AS vigente_de,
    data_fim                    AS vigente_ate,
    'historico'                 AS versao
FROM  investidor_historico
WHERE cpf_cnpj = '12345678901'

UNION ALL

SELECT
    cpf_cnpj,
    nome,
    data_atualizacao            AS vigente_de,
    NULL                        AS vigente_ate,
    'atual'                     AS versao
FROM  investidor
WHERE cpf_cnpj = '12345678901'

ORDER BY vigente_de;


-- =============================================================================
-- 8. CONSULTA POINT-IN-TIME (SCD TYPE 2)
-- Retorna o estado dos dados mestres em uma data específica no passado.
-- Busca no historico se a data alvo caía dentro de um período de vigência;
-- usa a tabela principal se a data alvo é posterior à última atualização.
-- =============================================================================

-- 8a. Qual era o setor da Petrobras em 2026-03-01? (antes da reclassificação)
SELECT nome, setor, 'historico' AS fonte
FROM   empresa_historico
WHERE  cnpj        = '33000167000101'
  AND  data_inicio <= '2026-03-01'::TIMESTAMP
  AND  data_fim    >  '2026-03-01'::TIMESTAMP

UNION ALL

SELECT nome, setor, 'atual' AS fonte
FROM   empresa
WHERE  cnpj             = '33000167000101'
  AND  data_atualizacao <= '2026-03-01'::TIMESTAMP;
-- Resultado esperado: Petróleo Brasileiro SA | Energia


-- 8b. Qual era o nome do investidor em 2026-03-01? (antes da atualização)
SELECT nome, 'historico' AS fonte
FROM   investidor_historico
WHERE  cpf_cnpj    = '12345678901'
  AND  data_inicio <= '2026-03-01'::TIMESTAMP
  AND  data_fim    >  '2026-03-01'::TIMESTAMP

UNION ALL

SELECT nome, 'atual' AS fonte
FROM   investidor
WHERE  cpf_cnpj         = '12345678901'
  AND  data_atualizacao <= '2026-03-01'::TIMESTAMP;
-- Resultado esperado: Fernando Garbo
