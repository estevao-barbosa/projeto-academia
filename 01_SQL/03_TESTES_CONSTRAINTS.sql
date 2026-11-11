/* Testes das regras de negócio do banco ACADEMIA.

Pré-requisito: 01_CRIACAO.sql e 02_DADOS.sql executados.
Como ler: cada teste imprime OK ou FALHOU na aba Mensagens.
Todos terminam em ROLLBACK e não alteram os dados.

Cobertura: multa de pagamento, trancamento, contrato, manutenção,
capacidade das aulas (trigger), idade mínima do aluno e view de idade.
Não coberto (por amostragem): CPF, conflito de horário do instrutor,
chaves estrangeiras, domínios (plano e dia da semana), DEFAULT do
trancamento e idade mínima de instrutor e personal.*/
   
USE ACADEMIA
GO

--TESTE 01 -> Pagamento atrasado com multa zero (CK_PAGAMENTO_VALOR_MULTA_COERENTE)


BEGIN TRY
	BEGIN TRANSACTION;

	INSERT INTO PAGAMENTO (ID_ALUNO,VALOR_PAGO,DATA_DE_VENCIMENTO,DATA_DE_PAGAMENTO,VALOR_MULTA)
	VALUES((SELECT MAX(ID_ALUNO) FROM ALUNO), 99.90,'2025-11-10','2025-11-11',0 );

    PRINT 'FALHOU: o banco aceitou pagamento atrasado com multa 0';
    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE '%CK_PAGAMENTO_VALOR_MULTA_COERENTE%'
        PRINT 'OK: recusado pela constraint onde pagamento atrasado não pode ter multa igual a 0 ';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 02 -> pagamento em dia com multa maior que zero (CK_PAGAMENTO_VALOR_MULTA_COERENTE)

BEGIN TRY
	BEGIN TRANSACTION

	    INSERT INTO PAGAMENTO (ID_ALUNO,VALOR_PAGO,DATA_DE_VENCIMENTO,DATA_DE_PAGAMENTO,VALOR_MULTA) 
	    VALUES((SELECT MAX(ID_ALUNO) FROM ALUNO), 99.90,'2025-11-10','2025-11-09',2.00 );            

        PRINT 'FALHOU: o banco aceitou multa em pagamento onde não houve atraso';

    ROLLBACK TRANSACTION
END TRY

BEGIN CATCH
    IF ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE '%CK_PAGAMENTO_VALOR_MULTA_COERENTE%'
        PRINT 'OK: recusado pela constraint onde pagamento feito em dia não pode ter multa maior que 0 ';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 03 -> Segundo trancamento em aberto para o mesmo aluno deve ser recusado (UX_TRANCAMENTO_ALUNO_ABERTA)

DECLARE @ID_ALUNO INT = (
    SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
    WHERE NOT EXISTS (SELECT T.ID_ALUNO FROM TRANCAMENTO AS T 
                        WHERE A.ID_ALUNO = T.ID_ALUNO AND T.DATA_FIM_TRANCAMENTO IS NULL)
ORDER BY A.ID_ALUNO ASC
);

BEGIN TRY
    BEGIN TRANSACTION;

        -- 1º trancamento em aberto: deve ser aceito
        INSERT INTO TRANCAMENTO (ID_ALUNO,DATA_INICIO_TRANCAMENTO,DATA_FIM_TRANCAMENTO)
        VALUES(@ID_ALUNO,CAST(GETDATE() AS DATE),NULL);

        --2º trancamento em aberto do mesmo aluno: deve ser recusado

        INSERT INTO TRANCAMENTO (ID_ALUNO,DATA_INICIO_TRANCAMENTO,DATA_FIM_TRANCAMENTO)
        VALUES(@ID_ALUNO,CAST(GETDATE() AS DATE),NULL);
        
        PRINT 'FALHOU: o banco aceitou o mesmo aluno ter dois trancamentos em aberto';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH 
    IF ERROR_MESSAGE() LIKE '%UX_TRANCAMENTO_ALUNO_ABERTA%'
        PRINT 'OK: recusado pelo índice onde não permite que o mesmo aluno tenha mais de 1 trancamento em aberto';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 03.1 -> O aluno pode ter mais de 1 trancamento desde que apenas um único trancamento esteja em aberto (UX_TRANCAMENTO_ALUNO_ABERTA)

DECLARE @ID_ALUNO INT = (
    SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
    WHERE NOT EXISTS (SELECT T.ID_ALUNO FROM TRANCAMENTO AS T 
                        WHERE A.ID_ALUNO = T.ID_ALUNO AND T.DATA_FIM_TRANCAMENTO IS NULL)
ORDER BY A.ID_ALUNO ASC
);

BEGIN TRY
    BEGIN TRANSACTION;

        -- 1º trancamento em aberto: deve ser aceito
        INSERT INTO TRANCAMENTO (ID_ALUNO,DATA_INICIO_TRANCAMENTO,DATA_FIM_TRANCAMENTO)
        VALUES(@ID_ALUNO, CAST(GETDATE() AS DATE), NULL);

        --2º trancamento encerrado do mesmo aluno: também deve ser aceito

        INSERT INTO TRANCAMENTO (ID_ALUNO,DATA_INICIO_TRANCAMENTO,DATA_FIM_TRANCAMENTO)
        VALUES(@ID_ALUNO, CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE));
        
        PRINT 'OK: o banco aceitou o mesmo aluno ter um trancamento em aberto e outro encerrado';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH 
    IF ERROR_MESSAGE() LIKE '%UX_TRANCAMENTO_ALUNO_ABERTA%'
        PRINT 'FALHOU: o banco recusou que aluno tivesse mais de 1 trancamento registrado, mesmo que um deles seja encerrado. Erro: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 04 ->  Trancamento com fim antes do início (CK_TRANCAMENTO_DATA_FIM_TRANCAMENTO)

DECLARE @ID_ALUNO INT = (SELECT TOP 1 ID_ALUNO FROM ALUNO ORDER BY ID_ALUNO ASC)

BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO TRANCAMENTO (ID_ALUNO,DATA_INICIO_TRANCAMENTO,DATA_FIM_TRANCAMENTO)
        VALUES(@ID_ALUNO, CAST(GETDATE() AS date),DATEADD(DAY,-1,CAST(GETDATE() AS DATE)));

        PRINT 'FALHOU: o banco aceitou que a data fim do trancamento seja anterior à data de inicio de trancamento';

     ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_TRANCAMENTO_DATA_FIM_TRANCAMENTO%'
        PRINT 'OK: recusado pela constraint onde a fim do trancamento nunca pode ser anterior a data do inicio do trancamento';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO
 
 --TESTE 05 -> segundo contrato em aberto para o mesmo aluno com o mesmo personal deve ser recusado (UX_CONTRATO_ALUNO_PERSONAL_ABERTO)


 DECLARE @ID_ALUNO INT = (SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
                            WHERE NOT EXISTS(SELECT C.NUMERO_CONTRATO FROM CONTRATO AS C 
                                                    WHERE A.ID_ALUNO = C.ID_ALUNO AND C.FIM_CONTRATO IS NULL)
                                                        ORDER BY A.ID_ALUNO ASC);

 DECLARE @ID_PERSONAL INT = (SELECT MAX(ID_PERSONAL) FROM PERSONAL);

 BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO CONTRATO (ID_ALUNO,ID_PERSONAL,VALOR_CONTRATO,INICIO_CONTRATO,FIM_CONTRATO)
        VALUES(@ID_ALUNO,@ID_PERSONAL,100.00,CAST(GETDATE() AS DATE), NULL);

        INSERT INTO CONTRATO (ID_ALUNO,ID_PERSONAL,VALOR_CONTRATO,INICIO_CONTRATO,FIM_CONTRATO)
        VALUES(@ID_ALUNO,@ID_PERSONAL,100.00,CAST(GETDATE() AS DATE), NULL);

        PRINT 'FALHOU: o banco aceitou dois contratos do mesmo aluno com o mesmo personal em aberto';

    ROLLBACK TRANSACTION;
 END TRY

 BEGIN CATCH

    IF ERROR_MESSAGE() LIKE '%UX_CONTRATO_ALUNO_PERSONAL_ABERTO%'
        PRINT 'OK: recusado pelo índice que não permite mais de 1 contrato em aberto entre o mesmo aluno e personal';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 END CATCH;
 GO

 --TESTE 05.1 -> segundo contrato entre o mesmo aluno e personal deve ser aceito, desde que no máximo 1 esteja em aberto (UX_CONTRATO_ALUNO_PERSONAL_ABERTO)

 DECLARE @ID_ALUNO INT = (SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
                            WHERE NOT EXISTS(SELECT C.NUMERO_CONTRATO FROM CONTRATO AS C 
                                                    WHERE A.ID_ALUNO = C.ID_ALUNO AND C.FIM_CONTRATO IS NULL)
                                                        ORDER BY A.ID_ALUNO ASC);

 DECLARE @ID_PERSONAL INT = (SELECT MAX(ID_PERSONAL) FROM PERSONAL);

 BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO CONTRATO (ID_ALUNO,ID_PERSONAL,VALOR_CONTRATO,INICIO_CONTRATO,FIM_CONTRATO,STATUS_CONTRATO)
        VALUES(@ID_ALUNO,@ID_PERSONAL,100.00,CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE) , 'INATIVO');

        INSERT INTO CONTRATO (ID_ALUNO,ID_PERSONAL,VALOR_CONTRATO,INICIO_CONTRATO,FIM_CONTRATO,STATUS_CONTRATO)
        VALUES(@ID_ALUNO,@ID_PERSONAL,100.00,CAST(GETDATE() AS DATE), NULL,'ATIVO');

        PRINT 'OK: o banco aceitou um contrato encerrado e outro em aberto para o mesmo aluno e o mesmo personal';

    ROLLBACK TRANSACTION;
 END TRY

 BEGIN CATCH

    IF ERROR_MESSAGE() LIKE '%UX_CONTRATO_ALUNO_PERSONAL_ABERTO%'
        PRINT 'FALHOU: o índice recusou que o aluno tivesse dois contratos com o mesmo personal, mesmo apenas 1 estando ativo';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 END CATCH;
 GO

 --TESTE 05.2 -> Contrato ATIVO com data de fim deve ser recusado (CK_CONTRATO_STATUS_CONTRATO)

 DECLARE @ID_ALUNO INT = (SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
                            WHERE NOT EXISTS(SELECT C.NUMERO_CONTRATO FROM CONTRATO AS C 
                                                    WHERE A.ID_ALUNO = C.ID_ALUNO AND C.FIM_CONTRATO IS NULL)
                                                        ORDER BY A.ID_ALUNO ASC);

 DECLARE @ID_PERSONAL INT = (SELECT MAX(ID_PERSONAL) FROM PERSONAL);

 BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO CONTRATO (ID_ALUNO,ID_PERSONAL,VALOR_CONTRATO,INICIO_CONTRATO,FIM_CONTRATO,STATUS_CONTRATO)
        VALUES(@ID_ALUNO,@ID_PERSONAL,100.00,DATEADD(DAY,-1,CAST(GETDATE() AS DATE)),CAST(GETDATE() AS DATE),'ATIVO');

        PRINT 'FALHOU: o banco aceitou um contrato com data final como ATIVO';

    ROLLBACK TRANSACTION;
 END TRY

 BEGIN CATCH

    IF ERROR_MESSAGE() LIKE '%CK_CONTRATO_STATUS_CONTRATO%'
        PRINT 'OK: o banco recusou um contrato com data final como ATIVO';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
 END CATCH;
 GO


 --TESTE 06 -> Manutenção concluída com relatório vazio deve ser recusado	(CK_MANUTENCAO_RELATORIO_OBRIGATORIO)

DECLARE @ID_EQUIPAMENTO  INT = (SELECT TOP 1 ID_EQUIPAMENTO  FROM EQUIPAMENTO  ORDER BY ID_EQUIPAMENTO);

DECLARE @ID_TERCEIRIZADO INT = (SELECT MAX(ID_TERCEIRIZADO) FROM TERCEIRIZADO);

BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO MANUTENCAO (ID_EQUIPAMENTO,ID_TERCEIRIZADO,DATA_REQUISICAO,DATA_FIM_MANUTENCAO,DESCRICAO_PROBLEMA,RELATORIO_DO_QUE_FOI_FEITO)
        VALUES(@ID_EQUIPAMENTO,@ID_TERCEIRIZADO, DATEADD(DAY,-1,CAST(GETDATE() AS DATE)),CAST(GETDATE() AS DATE),'peça quebrada','');

        PRINT 'FALHOU: o banco aceitou o relatório vazio, mesmo que a manutenção já tenha sido concluída';

ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_MANUTENCAO_RELATORIO_OBRIGATORIO%'
        PRINT 'OK: o banco recusou que uma manutenção realizada fosse inserida sem o relatório';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

 --TESTE 06.1 -> Manutenção concluída com relatório NULO deve ser recusado (CK_MANUTENCAO_RELATORIO_OBRIGATORIO)


DECLARE @ID_EQUIPAMENTO  INT = (SELECT TOP 1 ID_EQUIPAMENTO  FROM EQUIPAMENTO  ORDER BY ID_EQUIPAMENTO);

DECLARE @ID_TERCEIRIZADO INT = (SELECT MAX(ID_TERCEIRIZADO) FROM TERCEIRIZADO);

BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO MANUTENCAO (ID_EQUIPAMENTO,ID_TERCEIRIZADO,DATA_REQUISICAO,DATA_FIM_MANUTENCAO,DESCRICAO_PROBLEMA,RELATORIO_DO_QUE_FOI_FEITO)
        VALUES(@ID_EQUIPAMENTO,@ID_TERCEIRIZADO, DATEADD(DAY,-1,CAST(GETDATE() AS DATE)),CAST(GETDATE() AS DATE),'peça quebrada',NULL);

        PRINT 'FALHOU: o banco aceitou o relatório NULO, mesmo que a manutenção já tenha sido concluída';

ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_MANUTENCAO_RELATORIO_OBRIGATORIO%'
        PRINT 'OK: o banco recusou que uma manutenção realizada fosse inserida sem relatório (nulo)';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 06.2 -> Manutenção em aberto, com relatório preenchido, deve ser recusado (CK_MANUTENCAO_RELATORIO_OBRIGATORIO)

DECLARE @ID_EQUIPAMENTO INT = (SELECT TOP 1 E.ID_EQUIPAMENTO FROM EQUIPAMENTO AS E 
                                    WHERE NOT EXISTS (SELECT M.ID_EQUIPAMENTO FROM MANUTENCAO AS M
                                            WHERE E.ID_EQUIPAMENTO = M.ID_EQUIPAMENTO AND DATA_FIM_MANUTENCAO IS NULL)
                                                ORDER BY E.ID_EQUIPAMENTO ASC);

DECLARE @ID_TERCEIRIZADO INT = (SELECT MAX(ID_TERCEIRIZADO) FROM TERCEIRIZADO);

BEGIN TRY
    BEGIN TRANSACTION;
        
        INSERT INTO MANUTENCAO (ID_EQUIPAMENTO,ID_TERCEIRIZADO,DATA_REQUISICAO,DATA_FIM_MANUTENCAO,DESCRICAO_PROBLEMA,RELATORIO_DO_QUE_FOI_FEITO)
        VALUES(@ID_EQUIPAMENTO,@ID_TERCEIRIZADO, DATEADD(DAY,-1,CAST(GETDATE() AS DATE)),NULL,'peça quebrada','substituição da peça');

        PRINT 'FALHOU: o banco aceitou o relatório preenchido, mesmo que a manutenção ainda esteja em aberto';

ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_MANUTENCAO_RELATORIO_OBRIGATORIO%'
        PRINT 'OK: o banco recusou que uma manutenção em aberto fosse inserida com relatório preenchido';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 07 -> inscrição além da capacidade de uma aula coletiva deve ser recusada pela trigger (TGR_ALUNO_AULA_COLETIVA_CAPACIDADE)

DECLARE @ID_AULA INT = (SELECT TOP 1 ID_AULA FROM AULA_COLETIVA ORDER BY ID_AULA ASC);
DECLARE @CAPACIDADE INT = (SELECT CAPACIDADE_MAXIMA FROM AULA_COLETIVA WHERE @ID_AULA = ID_AULA);
DECLARE @INSCRITOS INT = (SELECT COUNT(ID_AULA) FROM ALUNO_AULA_COLETIVA WHERE @ID_AULA = ID_AULA);
DECLARE @ID_EXTRA INT;
DECLARE @PASSO INT = 0;

--1) preenchendo a aula_coletiva até a capacidade máxima

BEGIN TRY
    BEGIN TRANSACTION;
        SET @PASSO = 1;
        INSERT INTO ALUNO_AULA_COLETIVA (ID_ALUNO,ID_AULA)
        SELECT TOP (@CAPACIDADE - @INSCRITOS) A.ID_ALUNO, @ID_AULA 
        FROM ALUNO AS A WHERE NOT EXISTS 
            (SELECT AC.ID_ALUNO FROM ALUNO_AULA_COLETIVA AS AC WHERE A.ID_ALUNO = AC.ID_ALUNO AND @ID_AULA = AC.ID_AULA)
        ORDER BY A.ID_ALUNO ASC;

--2) adicionando mais um aluno na aula coletiva (o banco deve recusar)

        SET @PASSO = 2;
        SET @ID_EXTRA = (SELECT TOP 1 A.ID_ALUNO FROM ALUNO AS A 
                    WHERE NOT EXISTS(SELECT AC.ID_ALUNO FROM ALUNO_AULA_COLETIVA AS AC
                        WHERE A.ID_ALUNO = AC.ID_ALUNO AND @ID_AULA = AC.ID_AULA) ORDER BY A.ID_ALUNO ASC);

        INSERT INTO ALUNO_AULA_COLETIVA (ID_ALUNO,ID_AULA)
        VALUES(@ID_EXTRA,@ID_AULA);

        PRINT 'FALHOU: a trigger não evitou que uma nova inscrição fosse inserida, mesmo excedendo a capacidade máxima';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF @PASSO = 2 AND (ERROR_PROCEDURE() = 'TGR_ALUNO_AULA_COLETIVA_CAPACIDADE' OR 
        ERROR_MESSAGE() LIKE '%Capacidade máxima da aula coletiva excedida.%')
        PRINT 'OK: a trigger impediu que a capacidade máxima da aula fosse excedida (erro ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
    ELSE IF @PASSO = 1
        PRINT 'FALHOU: trigger recusou preencher até a capacidade máxima (erro ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO


--TESTE 08 -> Aluno com idade menor que 12 anos deve ser recusado (CK_ALUNO_DATA_NASCIMENTO_ALUNO)

DECLARE @ID_PLANO INT = (SELECT TOP 1 ID_PLANO FROM PLANO ORDER BY ID_PLANO ASC);

BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO ALUNO(ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'JORGE','ALMEIDA','M',DATEADD(YEAR,-10,CAST(GETDATE() AS DATE)),'12345678901');

        PRINT 'FALHOU: o banco aceitou cadastro de aluno menor de 12 anos';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_ALUNO_DATA_NASCIMENTO_ALUNO%'
        PRINT 'OK: banco recusou cadastro de aluno menor de 12 anos';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 08.1 -> Aluno mesmo faltando 1 dia para fazer 12 anos deve ser recusado (CK_ALUNO_DATA_NASCIMENTO_ALUNO)

DECLARE @ID_PLANO INT = (SELECT TOP 1 ID_PLANO FROM PLANO ORDER BY ID_PLANO ASC);

BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO ALUNO(ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'CARLOS','FERREIRA','M',DATEADD(DAY,1,DATEADD(YEAR,-12,CAST(GETDATE() AS DATE))),'99999999012');

        PRINT 'FALHOU: o banco aceitou cadastro de aluno que só faz 12 anos amanhã';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_ALUNO_DATA_NASCIMENTO_ALUNO%'
        PRINT 'OK: banco recusou cadastro de aluno que só faz 12 anos amanhã';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 08.2 -> Aluno fazendo 12 anos de idade na data atual deve ser aceito (CK_ALUNO_DATA_NASCIMENTO_ALUNO)

DECLARE @ID_PLANO INT = (SELECT TOP 1 ID_PLANO FROM PLANO ORDER BY ID_PLANO ASC);

BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO ALUNO(ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'MARIA','BARBOSA','F',DATEADD(YEAR,-12,CAST(GETDATE() AS DATE)),'88888888845');

        PRINT 'OK: o banco aceitou cadastro de aluno que está fazendo 12 anos na data atual';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%CK_ALUNO_DATA_NASCIMENTO_ALUNO%'
        PRINT 'FALHOU: banco recusou cadastro de aluno que está fazendo 12 anos na data atual';
    ELSE
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--TESTE 09 -> View de idade: aniversário hoje, amanhã e ontem


DECLARE @HOJE DATE = CAST(GETDATE() AS DATE);
DECLARE @BASE DATE = DATEADD(YEAR,-20,@HOJE);
DECLARE @ID_PLANO INT = (SELECT TOP 1 ID_PLANO FROM PLANO ORDER BY ID_PLANO ASC);
DECLARE @ID_HOJE INT, @ID_AMANHA INT, @ID_ONTEM INT;
DECLARE @IDADE_HOJE INT, @IDADE_AMANHA INT, @IDADE_ONTEM INT;


BEGIN TRY
    BEGIN TRANSACTION;

        INSERT INTO ALUNO (ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'teste_hoje', 'Idade','F', @BASE,'11111111102');
        SET @ID_HOJE = SCOPE_IDENTITY();

        INSERT INTO ALUNO (ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'Teste_amanha', 'Idade','F', DATEADD(DAY,1,@BASE),'11111111103');
        SET @ID_AMANHA = SCOPE_IDENTITY();

        INSERT INTO ALUNO (ID_PLANO,NOME_ALUNO,SOBRENOME_ALUNO,SEXO_ALUNO,DATA_NASCIMENTO_ALUNO,CPF_ALUNO)
        VALUES(@ID_PLANO,'teste_ontem', 'Idade','F', DATEADD(DAY,-1,@BASE),'11111111104');
        SET @ID_ONTEM = SCOPE_IDENTITY();

        SET @IDADE_HOJE = (SELECT IDADE_ALUNO FROM VW_ALUNO_COM_IDADE WHERE ID_ALUNO = @ID_HOJE);
        SET @IDADE_AMANHA = (SELECT IDADE_ALUNO FROM VW_ALUNO_COM_IDADE WHERE ID_ALUNO = @ID_AMANHA);
        SET @IDADE_ONTEM = (SELECT IDADE_ALUNO FROM VW_ALUNO_COM_IDADE WHERE ID_ALUNO = @ID_ONTEM);

        PRINT 'idades retornadas pela view: hoje = ' + CAST(@IDADE_HOJE AS VARCHAR(10))
        + ' | amanhã = ' + CAST(@IDADE_AMANHA AS VARCHAR(10))
        + ' | ontem = ' + CAST(@IDADE_ONTEM AS VARCHAR(10)); 
        
        IF @IDADE_HOJE = 20
            PRINT 'OK: aniversário hoje de 20 anos';
        ELSE
            PRINT 'FALHOU: aniversário hoje deveria dar 20 anos';

        IF @IDADE_AMANHA = 19
            PRINT 'OK: aniversário amanhã de 20 anos, atualmente com 19 anos';
        ELSE
            PRINT 'FALHOU: deveria ter idade de 19 anos, pois aniversário ainda é amanhã';

        IF @IDADE_ONTEM = 20
            PRINT 'OK: aniversário ontem foi de 20 anos';
        ELSE
            PRINT 'FALHOU: aniversário ontem deveria ter sido de 20 anos';

        IF @IDADE_ONTEM - @IDADE_AMANHA = 1
            PRINT 'OK: 1 ano de diferença entre quem fez aniversário ontem e quem faz aniversário amanhã';
        ELSE
            PRINT 'FALHOU: a diferença de idade entre ontem e amanhã deveria ser igual a 1';

    ROLLBACK TRANSACTION;
END TRY

BEGIN CATCH
        PRINT 'FALHOU (erro inesperado ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' +  ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION ;
END CATCH;
GO

--VERIFICAÇÃO FINAL

SELECT @@TRANCOUNT AS TRANSAÇÕES_ABERTAS; --esperado -> 0

SELECT COUNT(ID_ALUNO) AS QTD_DE_ALUNOS FROM ALUNO; --esperado -> 1000