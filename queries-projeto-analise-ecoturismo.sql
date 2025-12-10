-- 1.Calculo de receita total por mes
SELECT
	EXTRACT(MONTH FROM data_reserva) as mes,        -- extrai mes da data de reserva
	EXTRACT(YEAR FROM data_reserva) as ano,         -- extrai o ano da data de reserva
	-- calcula a receita total: qtd_pessoas * preco, arredonda para duas casas decimais
	ROUND(SUM(qtd_pessoas*preco)::numeric, 2) as receita_periodo 
FROM reservas as r
INNER JOIN ofertas as o ON r.id_oferta = o.id_oferta -- une a tabela reservas com a de ofertas
WHERE status = 'concluída'                           -- filtro para apenas as reservas concluidas
GROUP BY ano, mes                                    -- agrupa o calculo por mes e ano
ORDER BY ano, mes                                    -- ordena por mes e ano




-- 2.Ticket medio
SELECT
	-- calcula o ticket medio, considerando o valor gasto por pessoa
	ROUND((SUM(preco * qtd_pessoas)/SUM(qtd_pessoas))::numeric, 2) AS media_gasto 
FROM reservas as r
INNER JOIN ofertas as o ON r.id_oferta = o.id_oferta -- une a tabela reservas com a de ofertas
WHERE status = 'concluída'                           -- filtro para apenas as reservas concluidas




-- 3.Tipo de oferta mais popular entre os viajantes
-- CTE que calcula o numero total de reservas conluidas
WITH total_geral as (
	SELECT
		COUNT(tipo_oferta) as total_oferta                -- calculo do total de reservas
	FROM reservas as r
	INNER JOIN ofertas as o ON r.id_oferta = o.id_oferta -- une a tabela reservas com a de ofertas
	WHERE status = 'concluída'                           -- filtro para apenas as reservas concluidas
)
-- Calcula a quantidade e a porcentagem de cada tipo de oferta
SELECT
	tipo_oferta,
	COUNT(tipo_oferta) as qtd_oferta, -- calculo numero de reservas
	-- calcula o percentual de cada tipo, baseado no total de reservas da CTE
	ROUND((COUNT(tipo_oferta) * 1.0) / (total_oferta * 1.0)  * 100 ,2) as porcentagem 
FROM reservas as r
INNER JOIN ofertas as o ON r.id_oferta = o.id_oferta -- une a tabela reservas com a de ofertas
CROSS JOIN total_geral                               -- une com a CTE de total_geral
WHERE status = 'concluída'                           -- filtro para as reservas concluidas
GROUP BY tipo_oferta, total_oferta                   -- agrupa por tipo de oferta


-- 4.Qual a taxa de repeticao de clientes
-- CTE 1: identifica clientes que compraram novamente
WITH comprou_novamente AS (
  SELECT
    id_cliente,                                     -- identifica o cliente
    -- classifica se o cliente fez mais de uma reserva concluída
    CASE 
      WHEN COUNT(*) > 1 THEN 'SIM'                  -- se o cliente tem mais de uma reserva concluída
      ELSE 'NAO'                                   -- se o cliente tem apenas uma reserva concluída
    END AS comprou_dnv
  FROM reservas
  WHERE status = 'concluída'                       -- considera apenas reservas concluídas
  GROUP BY id_cliente                              -- agrupa por cliente (cada cliente será uma linha)
),
-- CTE 2: calcula o total de clientes únicos com reservas concluídas
total_clientes AS (
  SELECT 
    COUNT(DISTINCT id_cliente) AS total_clientes   -- conta quantos clientes únicos concluíram pelo menos uma reserva
  FROM reservas
  WHERE status = 'concluída'                       -- mesmo filtro para manter consistência
)
-- Query principal: calcula quantidade e porcentagem de clientes por categoria
SELECT
  c.comprou_dnv,                                   -- 'SIM' ou 'NAO' (se repetiu a compra)
  COUNT(*) AS qtd_clientes,                        -- quantos clientes estão em cada grupo ('SIM' ou 'NAO')
  t.total_clientes,                                -- total de clientes (valor único vindo da CTE total_clientes)
  -- calcula o percentual de cada grupo sobre o total de clientes
  ROUND( (COUNT(*)::numeric / t.total_clientes) * 100, 2) AS porcentagem

FROM comprou_novamente c
CROSS JOIN total_clientes t                        -- junta o total (única linha) a todas as linhas de comprou_novamente
GROUP BY c.comprou_dnv, t.total_clientes;          -- agrupa por tipo de cliente e total (necessário para agregações)



-- 5. Quais ofertas estao recebendo as melhores avaliacoes?
-- Calcula a media de nota para cada oferta
SELECT
	a.id_oferta,
	titulo,
	-- calcula a media da nota
	ROUND(AVG(nota) :: numeric,2)
FROM avaliacoes as a
INNER JOIN ofertas as o ON a.id_oferta = o.id_oferta -- une a tabela avaliacoes com a de ofertas
GROUP BY a.id_oferta, titulo  -- agrupa por oferta
ORDER BY AVG(nota) DESC       -- ordena das melhores para as piores medias


-- 6. Quantas ofertas de fato tem praticas sustentaveis implementadas
-- CTE que calcula o numero total de ofertas disponiveis
WITH total_ofertas as(
	SELECT
		COUNT(id_oferta) as total_ofertas -- calculo do total de ofertas disponiveis
	FROM ofertas
)
-- calcula a quantidade e a porcentagem de ofertas com praticas sustentaveis associadas
SELECT
	COUNT(DISTINCT o.id_oferta) as ofertas_com_pratica, -- conta ofertas unicas com praticas
	-- calcula o percentual de ofertas sustentaveis, baseadas no total de ofertas da CTE
	ROUND((COUNT(DISTINCT o.id_oferta) * 1.0) / (total_ofertas * 1.0)  * 100 ,2) as porcentagem
FROM ofertas as o
INNER JOIN oferta_pratica as of ON o.id_oferta = of.id_oferta -- une ofertas a praticas sustentaveis
CROSS JOIN total_ofertas -- une com a CTE de total_ofertas
GROUP BY total_ofertas   -- agrupa pelo total para calculo percentual

--7. Quais praticas sustentaveis aparecem com mais frequencia nas experiencias reservadas
-- CTE que identifica todas as praticas sustentaveis em reservas concluidas
WITH praticas_em_cada_oferta as(
	SELECT
		r.id_reserva,
		o.id_oferta,
		ps.descricao
	FROM reservas as r
	INNER JOIN ofertas as o ON r.id_oferta = o.id_oferta                    -- une reservas com ofertas
	INNER JOIN oferta_pratica as op ON op.id_oferta = o.id_oferta           -- une com oferta_pratica
	INNER JOIN praticas_sustentaveis as ps ON ps.id_pratica = op.id_pratica -- une com oraticas_sustentaveis
	WHERE status = 'concluída' -- filtro para apenas reservas concluidas
)
-- conta a frequencia de cada pratica sustentavel nas reservas
SELECT
	descricao,
	COUNT(descricao) as total_aparicoes -- conta quantas vezes cada pratica aparece
FROM praticas_em_cada_oferta
GROUP BY descricao                      -- agrupa por pratica
ORDER BY 2 DESC                         -- ordena da mais para a menos frequente



-- 8. Com que frequencia clientes fieis fazem novas reservas?
-- CTE que identifica os clientes considerados fieis (com mais de uma reserva concluida)
WITH clientes_fieis as(	
	SELECT
		id_cliente
	FROM reservas
	WHERE status = 'concluída'                          -- filtro para reservas concluidas
	GROUP BY id_cliente                                 -- agrupa por cliente para contar reservas
	HAVING COUNT(id_reserva) > 1                        -- filtra apenas clientes com mais de uma reserva
),
-- CTE que calcula o tempo entre reservas concluidas consecutivas de cada cliente fiel
tempo_entre_reservas as(
	SELECT
		id_reserva,
		cf.id_cliente,
		data_reserva,
		-- calcula a diferenca em dias entre uma reserva e a anterior do mesmo cliente
		data_reserva - LAG(data_reserva) OVER(
			PARTITION BY cf.id_cliente ORDER BY data_reserva ASC
			) as diferenca
	FROM reservas as r
	INNER JOIN clientes_fieis as cf on cf.id_cliente = r.id_cliente  -- une apenas com clientes fieis
	WHERE r.status = 'concluída'         -- filtro para reservas concluidas
),
-- CTE que calcula tempo medio de cada cliente
tempo_cliente as (
	SELECT
	    id_cliente,
	    ROUND(AVG(diferenca), 2) AS tempo_medio_entre_reservas
	FROM tempo_entre_reservas
	WHERE diferenca IS NOT NULL
	GROUP BY id_cliente
)
-- Calcula a media geral do tempo medio entre reservas de cada cliente
SELECT
	AVG(tempo_medio_entre_reservas) as tempo_medio_entre_reservas 
FROM tempo_cliente
WHERE tempo_medio_entre_reservas IS NOT NULL  



-- 9. Quais operadores se destacam por tipo de experiencia?
-- CTE que analisa o desempenho dos operadores dentro de cada categoria
WITH desempenho_operador as (
	SELECT
		op.id_operador,
		op.nome_fantasia,
		of.tipo_oferta,
		-- calcula a nota média de avaliação de cada operador
		ROUND(AVG(nota):: numeric, 2) as media,
		-- classifica os operadores por nota dentro de cada tipo de oferta
		RANK() OVER (PARTITION BY of.tipo_oferta ORDER BY AVG(a.nota) DESC) AS posicao
	FROM avaliacoes as a
	INNER JOIN ofertas as of ON a.id_oferta = of.id_oferta      -- une avaliações com ofertas
	INNER JOIN operadores as op ON op.id_operador = of.id_operador  -- une ofertas com operadores
	GROUP BY tipo_oferta, op.id_operador                       -- agrupa por categoria e operador
)
-- Seleciona os operadores mais bem rankeados de cada categoria
SELECT 
	posicao,
	tipo_oferta,
	nome_fantasia,
	media
FROM desempenho_operador
WHERE posicao <= 5                                            -- filtra apenas os 5 melhores de cada tipo
ORDER BY 2,1                                                  -- ordena por tipo de oferta e depois por posição