USE ACADEMIA
GO

-- 1) Quantos alunos existem em cada plano, e qual a participação percentual de cada plano no total?

DECLARE @total_alunos DECIMAL(10,2) = (SELECT COUNT(*) FROM ALUNO)

;WITH ALUNOS_POR_PLANO
AS
(
SELECT P.nome_plano,COUNT(A1.id_aluno) AS qtd_alunos
FROM ALUNO AS A1
INNER JOIN PLANO AS P ON A1.id_plano = P.id_plano
GROUP BY P.nome_plano
)
SELECT nome_plano, qtd_alunos, CAST((qtd_alunos/@total_alunos) * 100 AS DECIMAL (5,2)) AS percentual_do_total
FROM ALUNOS_POR_PLANO
GO

-- 2) Quantas aulas coletivas existem por unidade e modalidade, e qual a capacidade total de cada combinação?

SELECT U.nome_unidade,M.nome_modalidade,COUNT(AC.id_aula) AS qtd_de_aulas, SUM(AC.capacidade_maxima) AS capacidade_total
FROM AULA_COLETIVA AS AC
INNER JOIN UNIDADE AS U ON AC.id_unidade = U.id_unidade
INNER JOIN MODALIDADE AS M ON AC.id_modalidade = M.id_modalidade
GROUP BY U.nome_unidade,M.nome_modalidade
ORDER BY U.nome_unidade,M.nome_modalidade
GO

-- 3) Qual o faturamento (valor pago) e o total de multas arrecadadas em cada mês dos últimos 12 meses?

DECLARE @data_inicio DATE = 
(
SELECT DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(MAX(data_de_pagamento)), MONTH(MAX(data_de_pagamento)), 1)) FROM PAGAMENTO
);

SELECT YEAR(data_de_pagamento) AS ano,MONTH(data_de_pagamento) AS mes, SUM(valor_pago) AS total_pago,
	SUM(valor_multa) AS total_multa
FROM PAGAMENTO
WHERE data_de_pagamento >= @data_inicio
GROUP BY YEAR(data_de_pagamento),MONTH(data_de_pagamento)
ORDER BY ano ASC,mes ASC
GO

-- 4) Qual a taxa de ocupação (inscritos ÷ capacidade) de cada aula, e quais são as 10 mais lotadas e as 10 menos lotadas?

;WITH OCUPACAO
AS
(
SELECT AC.id_aula, COUNT(AAC.id_aluno) AS inscritos, AC.capacidade_maxima, 
	CAST(COUNT(AAC.id_aluno)* 100.00/AC.capacidade_maxima AS DECIMAL(5,2)) AS percentual_de_ocupacao
FROM AULA_COLETIVA AS AC
LEFT JOIN ALUNO_AULA_COLETIVA AS AAC ON AC.id_aula = AAC.id_aula
GROUP BY AC.id_aula,AC.capacidade_maxima
)
, CLASSIFICACAO
AS
(
SELECT *,
ROW_NUMBER() OVER(ORDER BY percentual_de_ocupacao ASC, id_aula ASC) AS rank_menor,
ROW_NUMBER() OVER(ORDER BY percentual_de_ocupacao DESC, id_aula ASC) AS rank_maior
FROM OCUPACAO 
)
SELECT 'MENOR OCUPAÇÃO' AS grupo, id_aula, inscritos,capacidade_maxima,percentual_de_ocupacao
FROM CLASSIFICACAO WHERE rank_menor <= 10
UNION ALL
SELECT 'MAIOR OCUPAÇÃO' AS grupo,id_aula, inscritos,capacidade_maxima,percentual_de_ocupacao
FROM CLASSIFICACAO WHERE rank_maior <= 10
ORDER BY grupo,id_aula
GO

--5) Quais equipamentos estão em estado RUIM ou QUEBRADO e sem manutenção em aberto? 

SELECT E.id_equipamento, E.marca, E.estado
FROM EQUIPAMENTO AS E
WHERE E.estado IN ('RUIM', 'QUEBRADO')
  AND NOT EXISTS (SELECT 1 FROM MANUTENCAO AS M 
					WHERE E.id_equipamento = M.id_equipamento AND M.data_fim_manutencao IS NULL )
GO

-- 6) Qual o faturamento mensal, com o total acumulado ao longo dos meses e a variação percentual em relação ao mês anterior?

;WITH FATURAMENTO_MENSAL
AS
(
SELECT FORMAT(data_de_pagamento,'yyyy-MM') AS data , SUM(valor_pago + valor_multa) AS faturamento
FROM PAGAMENTO
GROUP BY FORMAT(data_de_pagamento,'yyyy-MM')
),
FAT_COMPARADO_MES_ANTERIOR
AS
(
SELECT *,
LAG(faturamento,1) OVER(ORDER BY data) AS mes_anterior,
CAST((faturamento - LAG(faturamento,1) OVER(ORDER BY data))
/ NULLIF(LAG(faturamento,1) OVER(ORDER BY data),0) * 100 AS DECIMAL(5,2)) AS variacao_comparado_mes_ant
FROM FATURAMENTO_MENSAL
)
SELECT *, 
SUM(faturamento) OVER(ORDER BY data ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado
FROM FAT_COMPARADO_MES_ANTERIOR
ORDER BY data 
GO

--7) Qual o ranking de instrutores por número de alunos inscritos nas suas aulas, reiniciando a classificação em cada unidade?

;WITH QTD_ALUNOS_POR_INSTRUTOR
AS
(
SELECT U.nome_unidade,I.id_instrutor,CONCAT(nome_instrutor,' ',sobrenome_instrutor) AS nome_instrutor,
COUNT(DISTINCT AAC.id_aluno) AS qtd_alunos
FROM INSTRUTOR AS I
INNER JOIN AULA_COLETIVA AS AC ON I.id_instrutor = AC.id_instrutor
INNER JOIN UNIDADE AS U ON AC.id_unidade = U.id_unidade
LEFT JOIN ALUNO_AULA_COLETIVA AS AAC ON AC.id_aula = AAC.id_aula
GROUP BY U.nome_unidade,I.id_instrutor,CONCAT(nome_instrutor,' ',sobrenome_instrutor)
)
SELECT *,
DENSE_RANK() OVER(PARTITION BY nome_unidade ORDER BY qtd_alunos DESC) AS rank_instrutores
FROM QTD_ALUNOS_POR_INSTRUTOR
ORDER BY nome_unidade,rank_instrutores
GO

-- 8) Quais alunos tiveram 3 ou mais pagamentos em atraso nos últimos 12 meses, e quanto pagaram de multa no total?

DECLARE @data_inicio DATE = 
(
SELECT DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(MAX(data_de_pagamento)), MONTH(MAX(data_de_pagamento)), 1)) FROM PAGAMENTO
);

;WITH QUANTIDADES_ATRASOS
AS
(
SELECT id_aluno, COUNT(*) AS qtd_pgto_atrasados, SUM(valor_multa) AS tt_multa
FROM PAGAMENTO 
WHERE data_de_pagamento > data_de_vencimento AND data_de_pagamento >= @data_inicio
GROUP BY id_aluno
HAVING COUNT(*) >= 3
)
SELECT * FROM QUANTIDADES_ATRASOS
ORDER BY qtd_pgto_atrasados DESC
GO
