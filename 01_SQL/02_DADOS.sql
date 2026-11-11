/* =============================================================================
   02_DADOS.sql | Carga de dados FICTICIOS para o banco ACADEMIA

   Como usar:
   1. Rode antes o 01_CRIACAO.sql (banco recem-criado e vazio).
   2. Rode este arquivo inteiro. Ele roda numa unica transacao: se algo falhar,
      nada e gravado.
   3. Para repetir, apague e recrie o banco (o script nao limpa as tabelas).

   Como funciona (resumo):
   - #NUM e uma tabela de numeros (1 a 20000). Com ela, um unico
     INSERT ... SELECT gera centenas ou milhares de linhas.
   - CHECKSUM(NEWID()) gera numeros aleatorios, usados para sortear nomes,
     datas, planos etc. a partir de listas pequenas.
   - Todas as regras do 01_CRIACAO.sql sao respeitadas (CHECKs, UNIQUEs,
     indices filtrados e trigger de capacidade).

   Todos os dados sao inventados. Os CPFs e CNPJs seguem um padrao sintetico
   (zeros a esquerda / prefixo 99) e nao pertencem a pessoas ou empresas reais.

   Requer SQL Server 2016 ou superior (DROP TABLE IF EXISTS, DATEFROMPARTS).
   ============================================================================= */

USE ACADEMIA;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ---------------------------------------------------------------------------
-- PARAMETROS (altere para gerar mais ou menos dados)
-- ---------------------------------------------------------------------------
DECLARE @QTD_ALUNOS        INT  = 1000;   -- maximo: 20000
DECLARE @QTD_INSTRUTORES   INT  = 24;     -- minimo: 12 (a grade de aulas usa 12 instrutores por horario)
DECLARE @QTD_PERSONAIS     INT  = 40;
DECLARE @EQUIP_POR_UNIDADE INT  = 60;
DECLARE @HOJE              DATE = CAST(GETDATE() AS DATE);

-- Limpa tabelas temporarias de execucoes anteriores na mesma sessao
DROP TABLE IF EXISTS #NUM, #NOMES, #SOBRENOMES, #MARCAS, #MOTIVOS, #PROBLEMAS, #RELATORIOS,
                     #DIAS, #HORARIOS, #PLANOS, #UNIDADES, #CATEGORIAS, #TERCEIRIZADOS,
                     #MODALIDADES, #INSTRUTORES, #PERSONAIS, #EQUIPAMENTOS,
                     #INSTR_BASE, #PERS_BASE, #ALUNO_BASE, #PAG_BASE, #PAG_FINAL,
                     #TRANC_BASE, #CONT_BASE, #GRADE, #EQUIP_BASE, #MANUT_BASE, #MANUT_ABERTA_BASE;

BEGIN TRY
BEGIN TRANSACTION;

-- ---------------------------------------------------------------------------
-- 0) TABELA DE NUMEROS
-- ---------------------------------------------------------------------------
SELECT TOP (20000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS N
INTO #NUM
FROM sys.all_objects AS A
CROSS JOIN sys.all_objects AS B;

-- ---------------------------------------------------------------------------
-- 1) LISTAS AUXILIARES (de onde saem os sorteios)
-- ---------------------------------------------------------------------------
CREATE TABLE #NOMES (RN INT IDENTITY(1,1), NOME VARCHAR(50), SEXO CHAR(1));
INSERT INTO #NOMES (NOME, SEXO) VALUES
('Ana','F'),('Beatriz','F'),('Camila','F'),('Carolina','F'),('Daniela','F'),
('Eduarda','F'),('Fernanda','F'),('Gabriela','F'),('Helena','F'),('Isabela','F'),
('Juliana','F'),('Larissa','F'),('Letícia','F'),('Mariana','F'),('Natália','F'),
('Patrícia','F'),('Rafaela','F'),('Sabrina','F'),('Tatiana','F'),('Vanessa','F'),
('Alexandre','M'),('Bruno','M'),('Carlos','M'),('Daniel','M'),('Eduardo','M'),
('Felipe','M'),('Gabriel','M'),('Henrique','M'),('Igor','M'),('João','M'),
('Leonardo','M'),('Lucas','M'),('Marcelo','M'),('Mateus','M'),('Pedro','M'),
('Rafael','M'),('Rodrigo','M'),('Thiago','M'),('Vinícius','M'),('Wesley','M');

CREATE TABLE #SOBRENOMES (RN INT IDENTITY(1,1), SOBRENOME VARCHAR(50));
INSERT INTO #SOBRENOMES (SOBRENOME) VALUES
('Silva'),('Santos'),('Oliveira'),('Souza'),('Pereira'),('Costa'),('Rodrigues'),
('Almeida'),('Nascimento'),('Lima'),('Araújo'),('Fernandes'),('Carvalho'),('Gomes'),
('Martins'),('Rocha'),('Ribeiro'),('Alves'),('Monteiro'),('Mendes'),('Barros'),
('Freitas'),('Barbosa'),('Pinto'),('Moreira'),('Cardoso'),('Teixeira'),('Correia'),
('Cavalcanti'),('Dias');

CREATE TABLE #MARCAS (RN INT IDENTITY(1,1), MARCA VARCHAR(50));
INSERT INTO #MARCAS (MARCA) VALUES
('TitanFit'),('AlphaGym'),('Vigor'),('IronCore'),('MaxForce'),
('ProStrong'),('EvoFit'),('PowerLine'),('FlexPro'),('BodyTech');

CREATE TABLE #MOTIVOS (RN INT IDENTITY(1,1), MOTIVO VARCHAR(200));
INSERT INTO #MOTIVOS (MOTIVO) VALUES
('Viagem prolongada'),('Lesão'),('Dificuldades financeiras'),
('Mudança de cidade'),('Motivos pessoais'),('Tratamento de saúde');

CREATE TABLE #PROBLEMAS (RN INT IDENTITY(1,1), PROBLEMA VARCHAR(200));
INSERT INTO #PROBLEMAS (PROBLEMA) VALUES
('Esteira não liga'),('Ruído excessivo no motor'),('Cabo de aço desgastado'),
('Estofado rasgado'),('Display com erro'),('Correia desalinhada'),
('Pedal solto'),('Regulagem de assento travada');

CREATE TABLE #RELATORIOS (RN INT IDENTITY(1,1), RELATORIO VARCHAR(200));
INSERT INTO #RELATORIOS (RELATORIO) VALUES
('Peça substituída e equipamento testado.'),('Lubrificação e ajuste realizados.'),
('Troca do cabo e calibragem concluídas.'),('Estofado reparado e equipamento liberado.'),
('Revisão geral e testes de funcionamento.');

CREATE TABLE #DIAS (RN INT IDENTITY(1,1), DIA VARCHAR(7));
INSERT INTO #DIAS (DIA) VALUES ('SEGUNDA'),('TERÇA'),('QUARTA'),('QUINTA'),('SEXTA'),('SÁBADO');

CREATE TABLE #HORARIOS (RN INT IDENTITY(1,1), HORA TIME(0));
INSERT INTO #HORARIOS (HORA) VALUES ('07:00'),('09:00'),('18:00'),('19:30');

-- ---------------------------------------------------------------------------
-- 2) TABELAS DE DOMINIO (dados fixos)
-- ---------------------------------------------------------------------------
INSERT INTO CIDADE (NOME_CIDADE, UF) VALUES
('Vila Velha','ES'),('Vitória','ES'),('Serra','ES'),('Cariacica','ES');

INSERT INTO CEP (CODIGO_CEP, NOME_RUA, BAIRRO, ID_CIDADE)
SELECT V.CEP, V.RUA, V.BAIRRO, C.ID_CIDADE
FROM (VALUES
    ('29101001','Avenida das Palmeiras','Praia da Costa','Vila Velha'),
    ('29102002','Rua dos Ipês','Itaparica','Vila Velha'),
    ('29103003','Avenida das Acácias','Jardim da Penha','Vitória'),
    ('29104004','Rua das Orquídeas','Jardim Camburi','Vitória'),
    ('29105005','Avenida dos Cajueiros','Laranjeiras','Serra'),
    ('29106006','Rua das Mangueiras','Campo Grande','Cariacica')
) AS V(CEP, RUA, BAIRRO, CIDADE)
JOIN CIDADE AS C ON C.NOME_CIDADE = V.CIDADE AND C.UF = 'ES';

INSERT INTO UNIDADE (NOME_UNIDADE, CODIGO_CEP, NUMERO_ENDERECO, COMPLEMENTO) VALUES
('Praia da Costa','29101001','100',NULL),
('Itaparica','29102002','250','Loja 1'),
('Jardim da Penha','29103003','1020',NULL),
('Jardim Camburi','29104004','75','Térreo'),
('Laranjeiras','29105005','410',NULL),
('Campo Grande','29106006','88','Loja 2');

INSERT INTO CATEGORIA (NOME_CATEGORIA) VALUES
('Esteira'),('Bicicleta Ergométrica'),('Elíptico'),('Supino'),('Leg Press'),
('Halteres'),('Cabo Crossover'),('Remo'),('Cadeira Extensora'),('Puxador');

INSERT INTO TERCEIRIZADO (NOME_EMPRESA, CNPJ) VALUES
('TechFit Manutenções','99000000000001'),
('Reparo Rápido Fitness','99000000000002'),
('ProGym Assistência Técnica','99000000000003'),
('Capixaba Equipamentos Técnicos','99000000000004'),
('Equilibrium Serviços','99000000000005');

INSERT INTO PLANO (NOME_PLANO, VALOR_PLANO) VALUES
('MENSAL',99.90),('TRIMESTRAL',269.90),('SEMESTRAL',499.90),('ANUAL',899.90);

INSERT INTO MODALIDADE (NOME_MODALIDADE) VALUES
('Spinning'),('Funcional'),('Yoga'),('Zumba'),
('Pilates Solo'),('Jump'),('Alongamento'),('Muay Thai Fitness');

-- Listas de IDs reais (nao assume que os IDs comecam em 1)
SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_PLANO) AS INT) AS RN, ID_PLANO, VALOR_PLANO,
       CASE NOME_PLANO WHEN 'MENSAL' THEN 1 WHEN 'TRIMESTRAL' THEN 3
                       WHEN 'SEMESTRAL' THEN 6 ELSE 12 END AS PERIODO
INTO #PLANOS FROM PLANO;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_UNIDADE) AS INT) AS RN, ID_UNIDADE
INTO #UNIDADES FROM UNIDADE;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_CATEGORIA) AS INT) AS RN, ID_CATEGORIA
INTO #CATEGORIAS FROM CATEGORIA;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_TERCEIRIZADO) AS INT) AS RN, ID_TERCEIRIZADO
INTO #TERCEIRIZADOS FROM TERCEIRIZADO;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_MODALIDADE) AS INT) AS RN, ID_MODALIDADE
INTO #MODALIDADES FROM MODALIDADE;

DECLARE @QTD_NOMES       INT = (SELECT COUNT(*) FROM #NOMES);
DECLARE @QTD_SOBRENOMES  INT = (SELECT COUNT(*) FROM #SOBRENOMES);
DECLARE @QTD_PLANOS      INT = (SELECT COUNT(*) FROM #PLANOS);
DECLARE @QTD_CATEGORIAS  INT = (SELECT COUNT(*) FROM #CATEGORIAS);
DECLARE @QTD_TERC        INT = (SELECT COUNT(*) FROM #TERCEIRIZADOS);
DECLARE @QTD_MODAL       INT = (SELECT COUNT(*) FROM #MODALIDADES);
DECLARE @QTD_MARCAS      INT = (SELECT COUNT(*) FROM #MARCAS);
DECLARE @QTD_MOTIVOS     INT = (SELECT COUNT(*) FROM #MOTIVOS);
DECLARE @QTD_PROBLEMAS   INT = (SELECT COUNT(*) FROM #PROBLEMAS);
DECLARE @QTD_RELATORIOS  INT = (SELECT COUNT(*) FROM #RELATORIOS);

-- ---------------------------------------------------------------------------
-- 3) INSTRUTORES (maiores de 18 anos)
-- ---------------------------------------------------------------------------
SELECT N.N,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_NOMES)      AS IDX_NOME,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_SOBRENOMES) AS IDX_SOBRE,
       ABS(CHECKSUM(NEWID()) % (45 * 365))          AS DIAS
INTO #INSTR_BASE
FROM #NUM AS N
WHERE N.N <= @QTD_INSTRUTORES;

INSERT INTO INSTRUTOR (NOME_INSTRUTOR, SOBRENOME_INSTRUTOR, SEXO_INSTRUTOR,
                       DATA_NASCIMENTO_INSTRUTOR, CPF_INSTRUTOR)
SELECT NM.NOME, SB.SOBRENOME, NM.SEXO,
       DATEADD(DAY, -B.DIAS, DATEADD(YEAR, -19, @HOJE)),
       RIGHT('00000000000' + CAST(B.N + 100000 AS VARCHAR(11)), 11)
FROM #INSTR_BASE AS B
JOIN #NOMES      AS NM ON NM.RN = B.IDX_NOME
JOIN #SOBRENOMES AS SB ON SB.RN = B.IDX_SOBRE
ORDER BY B.N;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_INSTRUTOR) AS INT) AS RN, ID_INSTRUTOR
INTO #INSTRUTORES FROM INSTRUTOR;

-- ---------------------------------------------------------------------------
-- 4) PERSONAIS (maiores de 18 anos)
-- ---------------------------------------------------------------------------
SELECT N.N,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_NOMES)      AS IDX_NOME,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_SOBRENOMES) AS IDX_SOBRE,
       ABS(CHECKSUM(NEWID()) % (45 * 365))          AS DIAS
INTO #PERS_BASE
FROM #NUM AS N
WHERE N.N <= @QTD_PERSONAIS;

INSERT INTO PERSONAL (NOME_PERSONAL, SOBRENOME_PERSONAL, SEXO_PERSONAL,
                      DATA_NASCIMENTO_PERSONAL, CPF_PERSONAL)
SELECT NM.NOME, SB.SOBRENOME, NM.SEXO,
       DATEADD(DAY, -B.DIAS, DATEADD(YEAR, -19, @HOJE)),
       RIGHT('00000000000' + CAST(B.N + 200000 AS VARCHAR(11)), 11)
FROM #PERS_BASE AS B
JOIN #NOMES      AS NM ON NM.RN = B.IDX_NOME
JOIN #SOBRENOMES AS SB ON SB.RN = B.IDX_SOBRE
ORDER BY B.N;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_PERSONAL) AS INT) AS RN, ID_PERSONAL
INTO #PERSONAIS FROM PERSONAL;

DECLARE @QTD_PERSONAIS_REAL INT = (SELECT COUNT(*) FROM #PERSONAIS);
DECLARE @QTD_INSTR_REAL     INT = (SELECT COUNT(*) FROM #INSTRUTORES);

-- ---------------------------------------------------------------------------
-- 5) ALUNOS (maiores de 12 anos; aqui, de 13 a 65 anos)
-- ---------------------------------------------------------------------------
SELECT N.N,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_NOMES)      AS IDX_NOME,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_SOBRENOMES) AS IDX_SOBRE,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_PLANOS)     AS IDX_PLANO,
       ABS(CHECKSUM(NEWID()) % (52 * 365))          AS DIAS
INTO #ALUNO_BASE
FROM #NUM AS N
WHERE N.N <= @QTD_ALUNOS;

INSERT INTO ALUNO (ID_PLANO, NOME_ALUNO, SOBRENOME_ALUNO, SEXO_ALUNO,
                   DATA_NASCIMENTO_ALUNO, CPF_ALUNO)
SELECT P.ID_PLANO, NM.NOME, SB.SOBRENOME, NM.SEXO,
       DATEADD(DAY, -B.DIAS, DATEADD(YEAR, -13, @HOJE)),
       RIGHT('00000000000' + CAST(B.N AS VARCHAR(11)), 11)
FROM #ALUNO_BASE AS B
JOIN #NOMES      AS NM ON NM.RN = B.IDX_NOME
JOIN #SOBRENOMES AS SB ON SB.RN = B.IDX_SOBRE
JOIN #PLANOS     AS P  ON P.RN  = B.IDX_PLANO
ORDER BY B.N;

-- ---------------------------------------------------------------------------
-- 6) PAGAMENTOS (ultimos 12 meses, conforme o periodo de cada plano)
--    ~75% pagos em dia (ate 5 dias antes do vencimento) e ~25% com atraso (multa de 2%)
-- ---------------------------------------------------------------------------
SELECT A.ID_ALUNO, P.VALOR_PLANO,
       DATEFROMPARTS(YEAR(DATEADD(MONTH, M.N - 12, @HOJE)),
                     MONTH(DATEADD(MONTH, M.N - 12, @HOJE)), 10) AS VENC,
       ABS(CHECKSUM(NEWID()) % 100)     AS SORTEIO,
       1 + ABS(CHECKSUM(NEWID()) % 20)  AS ATRASO,
       ABS(CHECKSUM(NEWID()) % 6)       AS ANTECIPA
INTO #PAG_BASE
FROM ALUNO AS A
JOIN #PLANOS AS P ON P.ID_PLANO = A.ID_PLANO
JOIN #NUM    AS M ON M.N BETWEEN 1 AND 12 AND (M.N - 1) % P.PERIODO = 0;

SELECT ID_ALUNO, VALOR_PLANO, VENC,
       CASE WHEN SORTEIO < 75 THEN DATEADD(DAY, -ANTECIPA, VENC)
            WHEN DATEADD(DAY, ATRASO, VENC) > @HOJE THEN @HOJE
            ELSE DATEADD(DAY, ATRASO, VENC) END AS DATA_PAG
INTO #PAG_FINAL
FROM #PAG_BASE
WHERE VENC <= @HOJE;

INSERT INTO PAGAMENTO (ID_ALUNO, VALOR_PAGO, DATA_DE_VENCIMENTO, DATA_DE_PAGAMENTO, VALOR_MULTA)
SELECT ID_ALUNO, VALOR_PLANO, VENC, DATA_PAG,
       CASE WHEN DATA_PAG > VENC THEN ROUND(VALOR_PLANO * 0.02, 2) ELSE 0 END
FROM #PAG_FINAL
ORDER BY ID_ALUNO, VENC;

-- ---------------------------------------------------------------------------
-- 7) TRANCAMENTOS: 100 alunos distintos (85 encerrados e 15 em aberto)
-- ---------------------------------------------------------------------------
SELECT T.ID_ALUNO,
       CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS RN,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_MOTIVOS) AS IDX_MOTIVO,
       60 + ABS(CHECKSUM(NEWID()) % 240)         AS DIAS_ATRAS,
       15 + ABS(CHECKSUM(NEWID()) % 31)          AS DURACAO,
       1 + ABS(CHECKSUM(NEWID()) % 30)           AS DIAS_ABERTO
INTO #TRANC_BASE
FROM (SELECT TOP (100) ID_ALUNO FROM ALUNO ORDER BY NEWID()) AS T;

INSERT INTO TRANCAMENTO (ID_ALUNO, DATA_INICIO_TRANCAMENTO, DATA_FIM_TRANCAMENTO, MOTIVO_DO_TRANCAMENTO)
SELECT B.ID_ALUNO,
       DATEADD(DAY, -B.DIAS_ATRAS, @HOJE),
       DATEADD(DAY, B.DURACAO, DATEADD(DAY, -B.DIAS_ATRAS, @HOJE)),
       M.MOTIVO
FROM #TRANC_BASE AS B
JOIN #MOTIVOS AS M ON M.RN = B.IDX_MOTIVO
WHERE B.RN <= 85;

INSERT INTO TRANCAMENTO (ID_ALUNO, DATA_INICIO_TRANCAMENTO, DATA_FIM_TRANCAMENTO, MOTIVO_DO_TRANCAMENTO)
SELECT B.ID_ALUNO,
       DATEADD(DAY, -B.DIAS_ABERTO, @HOJE),
       NULL,
       M.MOTIVO
FROM #TRANC_BASE AS B
JOIN #MOTIVOS AS M ON M.RN = B.IDX_MOTIVO
WHERE B.RN > 85;

-- ---------------------------------------------------------------------------
-- 8) CONTRATOS COM PERSONAL: 200 alunos distintos (60 ativos e 140 encerrados)
-- ---------------------------------------------------------------------------
SELECT T.ID_ALUNO,
       CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS RN,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_PERSONAIS_REAL) AS IDX_PERSONAL,
       ABS(CHECKSUM(NEWID()) % 6)                       AS FAIXA,
       ABS(CHECKSUM(NEWID()) % 150)                     AS DIAS_A,
       ABS(CHECKSUM(NEWID()) % 120)                     AS DUR
INTO #CONT_BASE
FROM (SELECT TOP (200) ID_ALUNO FROM ALUNO ORDER BY NEWID()) AS T;

INSERT INTO CONTRATO (ID_ALUNO, ID_PERSONAL, VALOR_CONTRATO, INICIO_CONTRATO, FIM_CONTRATO, STATUS_CONTRATO)
SELECT B.ID_ALUNO, P.ID_PERSONAL,
       150 + (B.FAIXA * 25),
       DATEADD(DAY, -(10 + B.DIAS_A), @HOJE),
       NULL,
       'ATIVO'
FROM #CONT_BASE AS B
JOIN #PERSONAIS AS P ON P.RN = B.IDX_PERSONAL
WHERE B.RN <= 60;

INSERT INTO CONTRATO (ID_ALUNO, ID_PERSONAL, VALOR_CONTRATO, INICIO_CONTRATO, FIM_CONTRATO, STATUS_CONTRATO)
SELECT B.ID_ALUNO, P.ID_PERSONAL,
       150 + (B.FAIXA * 25),
       DATEADD(DAY, -(250 + B.DIAS_A), @HOJE),
       DATEADD(DAY, 30 + B.DUR, DATEADD(DAY, -(250 + B.DIAS_A), @HOJE)),
       'INATIVO'
FROM #CONT_BASE AS B
JOIN #PERSONAIS AS P ON P.RN = B.IDX_PERSONAL
WHERE B.RN > 60;

-- ---------------------------------------------------------------------------
-- 9) AULAS COLETIVAS: 6 unidades x 2 salas x 6 dias x 4 horarios = 288 aulas
--    A distribuicao dos instrutores evita conflito de horario (UNIQUE).
-- ---------------------------------------------------------------------------
SELECT U.RN AS U_RN, U.ID_UNIDADE, S.SALA_N, D.RN AS D_RN, D.DIA, H.RN AS H_RN, H.HORA,
       15 + ABS(CHECKSUM(NEWID()) % 16) AS CAPACIDADE
INTO #GRADE
FROM #UNIDADES AS U
CROSS JOIN (VALUES (1), (2)) AS S(SALA_N)
CROSS JOIN #DIAS     AS D
CROSS JOIN #HORARIOS AS H;

INSERT INTO AULA_COLETIVA (ID_MODALIDADE, ID_UNIDADE, ID_INSTRUTOR, SALA,
                           DIA_DA_SEMANA, HORARIO, CAPACIDADE_MAXIMA)
SELECT M.ID_MODALIDADE, G.ID_UNIDADE, I.ID_INSTRUTOR,
       'Sala ' + CAST(G.SALA_N AS VARCHAR(1)),
       G.DIA, G.HORA, G.CAPACIDADE
FROM #GRADE AS G
JOIN #INSTRUTORES AS I
     ON I.RN = 1 + (((G.U_RN - 1) * 2 + (G.SALA_N - 1) + G.D_RN * 7 + G.H_RN * 5) % @QTD_INSTR_REAL)
JOIN #MODALIDADES AS M
     ON M.RN = 1 + ((G.U_RN + G.SALA_N + G.D_RN + G.H_RN) % @QTD_MODAL)
ORDER BY G.U_RN, G.D_RN, G.H_RN, G.SALA_N;

-- ---------------------------------------------------------------------------
-- 10) INSCRICOES EM AULAS: cada aula recebe ate 80% da capacidade
--     (a trigger de capacidade nunca e violada)
-- ---------------------------------------------------------------------------
INSERT INTO ALUNO_AULA_COLETIVA (ID_ALUNO, ID_AULA)
SELECT X.ID_ALUNO, X.ID_AULA
FROM (
    SELECT A.ID_AULA, A.CAPACIDADE_MAXIMA, AL.ID_ALUNO,
           ROW_NUMBER() OVER (PARTITION BY A.ID_AULA ORDER BY NEWID()) AS RN
    FROM AULA_COLETIVA AS A
    CROSS JOIN ALUNO AS AL
) AS X
WHERE X.RN <= (X.CAPACIDADE_MAXIMA * 8) / 10;

-- ---------------------------------------------------------------------------
-- 11) EQUIPAMENTOS
-- ---------------------------------------------------------------------------
SELECT U.ID_UNIDADE, N.N AS SEQ,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_CATEGORIAS) AS IDX_CAT,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_MARCAS)     AS IDX_MARCA,
       ABS(CHECKSUM(NEWID()) % 100)                 AS SORTEIO
INTO #EQUIP_BASE
FROM #UNIDADES AS U
JOIN #NUM AS N ON N.N <= @EQUIP_POR_UNIDADE;

INSERT INTO EQUIPAMENTO (ID_UNIDADE, ID_CATEGORIA, MARCA, ESTADO)
SELECT B.ID_UNIDADE, C.ID_CATEGORIA, M.MARCA,
       CASE WHEN B.SORTEIO < 25 THEN 'PRATICAMENTE NOVO'
            WHEN B.SORTEIO < 65 THEN 'BOM'
            WHEN B.SORTEIO < 85 THEN 'REGULAR'
            WHEN B.SORTEIO < 95 THEN 'RUIM'
            ELSE 'QUEBRADO' END
FROM #EQUIP_BASE AS B
JOIN #CATEGORIAS AS C ON C.RN = B.IDX_CAT
JOIN #MARCAS     AS M ON M.RN = B.IDX_MARCA
ORDER BY B.ID_UNIDADE, B.SEQ;

SELECT CAST(ROW_NUMBER() OVER (ORDER BY ID_EQUIPAMENTO) AS INT) AS RN, ID_EQUIPAMENTO
INTO #EQUIPAMENTOS FROM EQUIPAMENTO;

DECLARE @QTD_EQUIP INT = (SELECT COUNT(*) FROM #EQUIPAMENTOS);

-- ---------------------------------------------------------------------------
-- 12) MANUTENCOES: 200 concluidas + 15 em aberto (equipamentos distintos)
-- ---------------------------------------------------------------------------
SELECT N.N,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_EQUIP)      AS IDX_EQUIP,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_TERC)       AS IDX_TERC,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_PROBLEMAS)  AS IDX_PROB,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_RELATORIOS) AS IDX_REL,
       30 + ABS(CHECKSUM(NEWID()) % 700)            AS DIAS,
       1 + ABS(CHECKSUM(NEWID()) % 20)              AS DURACAO
INTO #MANUT_BASE
FROM #NUM AS N
WHERE N.N <= 200;

INSERT INTO MANUTENCAO (ID_EQUIPAMENTO, ID_TERCEIRIZADO, DATA_REQUISICAO, DATA_FIM_MANUTENCAO,
                        DESCRICAO_PROBLEMA, RELATORIO_DO_QUE_FOI_FEITO)
SELECT E.ID_EQUIPAMENTO, T.ID_TERCEIRIZADO,
       DATEADD(DAY, -B.DIAS, @HOJE),
       DATEADD(DAY, B.DURACAO, DATEADD(DAY, -B.DIAS, @HOJE)),
       P.PROBLEMA, R.RELATORIO
FROM #MANUT_BASE AS B
JOIN #EQUIPAMENTOS   AS E ON E.RN = B.IDX_EQUIP
JOIN #TERCEIRIZADOS  AS T ON T.RN = B.IDX_TERC
JOIN #PROBLEMAS      AS P ON P.RN = B.IDX_PROB
JOIN #RELATORIOS     AS R ON R.RN = B.IDX_REL
ORDER BY B.N;

SELECT X.ID_EQUIPAMENTO,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_TERC)      AS IDX_TERC,
       1 + ABS(CHECKSUM(NEWID()) % @QTD_PROBLEMAS) AS IDX_PROB,
       1 + ABS(CHECKSUM(NEWID()) % 20)             AS DIAS
INTO #MANUT_ABERTA_BASE
FROM (SELECT TOP (15) ID_EQUIPAMENTO
      FROM EQUIPAMENTO
      WHERE ESTADO IN ('RUIM','QUEBRADO')
      ORDER BY NEWID()) AS X;

INSERT INTO MANUTENCAO (ID_EQUIPAMENTO, ID_TERCEIRIZADO, DATA_REQUISICAO, DATA_FIM_MANUTENCAO,
                        DESCRICAO_PROBLEMA, RELATORIO_DO_QUE_FOI_FEITO)
SELECT B.ID_EQUIPAMENTO, T.ID_TERCEIRIZADO,
       DATEADD(DAY, -B.DIAS, @HOJE),
       NULL,
       P.PROBLEMA,
       NULL
FROM #MANUT_ABERTA_BASE AS B
JOIN #TERCEIRIZADOS AS T ON T.RN = B.IDX_TERC
JOIN #PROBLEMAS     AS P ON P.RN = B.IDX_PROB;

COMMIT TRANSACTION;

-- ---------------------------------------------------------------------------
-- CONFERENCIA: linhas por tabela
-- ---------------------------------------------------------------------------
SELECT 'CIDADE' AS TABELA, COUNT(*) AS LINHAS FROM CIDADE
UNION ALL SELECT 'CEP',                 COUNT(*) FROM CEP
UNION ALL SELECT 'UNIDADE',             COUNT(*) FROM UNIDADE
UNION ALL SELECT 'CATEGORIA',           COUNT(*) FROM CATEGORIA
UNION ALL SELECT 'TERCEIRIZADO',        COUNT(*) FROM TERCEIRIZADO
UNION ALL SELECT 'PLANO',               COUNT(*) FROM PLANO
UNION ALL SELECT 'MODALIDADE',          COUNT(*) FROM MODALIDADE
UNION ALL SELECT 'INSTRUTOR',           COUNT(*) FROM INSTRUTOR
UNION ALL SELECT 'PERSONAL',            COUNT(*) FROM PERSONAL
UNION ALL SELECT 'ALUNO',               COUNT(*) FROM ALUNO
UNION ALL SELECT 'PAGAMENTO',           COUNT(*) FROM PAGAMENTO
UNION ALL SELECT 'TRANCAMENTO',         COUNT(*) FROM TRANCAMENTO
UNION ALL SELECT 'CONTRATO',            COUNT(*) FROM CONTRATO
UNION ALL SELECT 'AULA_COLETIVA',       COUNT(*) FROM AULA_COLETIVA
UNION ALL SELECT 'ALUNO_AULA_COLETIVA', COUNT(*) FROM ALUNO_AULA_COLETIVA
UNION ALL SELECT 'EQUIPAMENTO',         COUNT(*) FROM EQUIPAMENTO
UNION ALL SELECT 'MANUTENCAO',          COUNT(*) FROM MANUTENCAO;

SELECT TOP (5) * FROM VW_ALUNO_COM_IDADE ORDER BY ID_ALUNO;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
