-- Passo inicial para montagem tabela para log sistema restaurante
DROP TABLE tb_cliente;
CREATE TABLE tb_cliente (
	cod_cliente SERIAL PRIMARY KEY,
	nome VARCHAR(200) NOT NULL
);

SELECT * FROM tb_pedido;
DROP TABLE tb_pedido;
CREATE TABLE IF NOT EXISTS tb_pedido(
	cod_pedido SERIAL PRIMARY KEY,
	data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	data_modificacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	status VARCHAR DEFAULT 'aberto',
	cod_cliente INT NOT NULL,
	CONSTRAINT fk_cliente FOREIGN KEY (cod_cliente) REFERENCES
tb_cliente(cod_cliente)
);

DROP TABLE tb_tipo_item;
CREATE TABLE tb_tipo_item(
	cod_tipo SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL
);
INSERT INTO tb_tipo_item (descricao) VALUES ('Bebida'), ('Comida');
SELECT * FROM tb_tipo_item;
DROP TABLE tb_item;
CREATE TABLE IF NOT EXISTS tb_item(
	cod_item SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL,
	valor NUMERIC (10, 2) NOT NULL,
	cod_tipo INT NOT NULL,
	CONSTRAINT fk_tipo_item FOREIGN KEY (cod_tipo) REFERENCES
tb_tipo_item(cod_tipo)
);
INSERT INTO tb_item (descricao, valor, cod_tipo) VALUES
('Refrigerante', 7, 1), ('Suco', 8, 1), ('Hamburguer', 12, 2), ('Batata frita', 9, 2);
SELECT * FROM tb_item;

DROP TABLE tb_item_pedido;
CREATE TABLE IF NOT EXISTS tb_item_pedido(
	--surrogate key para cod_item pode repetir
	cod_item_pedido SERIAL PRIMARY KEY,
	cod_item INT,
	cod_pedido INT,
	CONSTRAINT fk_item FOREIGN KEY (cod_item) REFERENCES tb_item (cod_item),
	CONSTRAINT fk_pedido FOREIGN KEY (cod_pedido) REFERENCES tb_pedido
(cod_pedido)
);


-- Cadastro de cliente. Se parâmetro com valor DEFAULT é especificado, aqueles que aparecem dps tb deve ter valor DEFAULT
CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente (IN nome VARCHAR(200), IN
codigo INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
	IF codigo IS NULL THEN
		INSERT INTO tb_cliente (nome) VALUES (nome);
	ELSE
		INSERT INTO tb_cliente (codigo, nome) VALUES (codigo, nome);
	END IF;
END;
$$
CALL sp_cadastrar_cliente ('João da Silva');
CALL sp_cadastrar_cliente ('Maria Santos');
SELECT * FROM tb_cliente;

-- criando pedido da mesma forma que o cliente entrasse no restaurante e retirasse a comanda
CREATE OR REPLACE PROCEDURE sp_criar_pedido (OUT cod_pedido INT, cod_cliente INT)
LANGUAGE plpgsql
AS $$
BEGIN
		INSERT INTO tb_pedido (cod_cliente) VALUES (cod_cliente);
		-- obtém último valor gerado por SERIAL
		SELECT LASTVAL() INTO cod_pedido;
END;
$$

DO
$$
DECLARE
		-- guardando o código de pedido gerado
		cod_pedido INT;
		-- código do cliente que fará o pedido
		cod_cliente INT;
BEGIN
		-- pega o código da pessoa com nome "João da Silva"
		SELECT c.cod_cliente FROM tb_cliente c WHERE nome LIKE 'João da Silva' INTO cod_cliente;
		--criando pedido
		CALL sp_criar_pedido (cod_pedido, cod_cliente);
		RAISE NOTICE 'Código do pedido recém criado: %', cod_pedido;
END;
$$

-- adicionando item ao pedido
CREATE OR REPLACE PROCEDURE sp_adicionar_item_a_pedido (IN cod_item INT, IN
cod_pedido INT)
LANGUAGE plpgsql
AS $$
BEGIN
		--inserindo novo item
		INSERT INTO tb_item_pedido (cod_item, cod_pedido) VALUES ($1, $2);
		--atualizando data de modificação do pedido
		UPDATE tb_pedido p SET data_modificacao = CURRENT_TIMESTAMP WHERE
p.cod_pedido = $2;
END;
$$

CALL sp_adicionar_item_a_pedido (1, 1);
SELECT * FROM tb_item_pedido;
SELECT * FROM tb_pedido;

--calculando valor total do pedido
DROP PROCEDURE sp_calcular_valor_de_um_pedido;
CREATE OR REPLACE PROCEDURE sp_calcular_valor_de_um_pedido (IN p_cod_pedido
INT, OUT valor_total INT)
LANGUAGE plpgsql
AS $$
BEGIN
	SELECT SUM(valor) FROM
		tb_pedido p
		INNER JOIN tb_item_pedido ip ON
		p.cod_pedido = ip.cod_pedido
		INNER JOIN tb_item i ON
		i.cod_item = ip.cod_item
		WHERE p.cod_pedido = $1
		INTO $2;
END;
$$

DO $$
DECLARE
	valor_total INT;
BEGIN
	CALL sp_calcular_valor_de_um_pedido(1, valor_total);
	RAISE NOTICE 'Total do pedido %: R$%', 1, valor_total;
END;
$$

CREATE OR REPLACE PROCEDURE sp_fechar_pedido (IN valor_a_pagar INT, IN
cod_pedido INT)
LANGUAGE plpgsql
AS $$
DECLARE
	valor_total INT;
BEGIN
	--verificando valor_a_pagar é suficiente
	CALL sp_calcular_valor_de_um_pedido (cod_pedido, valor_total);
	IF valor_a_pagar < valor_total THEN
		RAISE 'R$% insuficiente para pagar a conta de R$%', valor_a_pagar,
valor_total;
	ELSE
		UPDATE tb_pedido p SET
		data_modificacao = CURRENT_TIMESTAMP,
		status = 'fechado'
		WHERE p.cod_pedido = $2;
	END IF;
END;
$$

DO $$
BEGIN
	CALL sp_fechar_pedido(200, 1);
END;
$$
SELECT * FROM tb_pedido;

CREATE OR REPLACE PROCEDURE sp_calcular_troco (OUT troco INT, IN valor_a_pagar
INT, IN valor_total INT)
LANGUAGE plpgsql
AS $$
BEGIN
	troco := valor_a_pagar - valor_total;
END;
$$

DO
$$
DECLARE
troco INT;
valor_total INT;
valor_a_pagar INT := 100;
BEGIN
	CALL sp_calcular_valor_de_um_pedido(1, valor_total);
	CALL sp_calcular_troco (troco, valor_a_pagar, valor_total);
	RAISE NOTICE 'A conta foi de R$% e você pagou %, portanto, seu troco é de R$%.',
valor_total, valor_a_pagar, troco;
END;
$$

CREATE OR REPLACE PROCEDURE sp_obter_notas_para_compor_o_troco (OUT resultado
VARCHAR(500), IN troco INT)
LANGUAGE plpgsql
AS $$
DECLARE
	notas200 INT := 0;
	notas100 INT := 0;
	notas50 INT := 0;
	notas20 INT := 0;
	notas10 INT := 0;
	notas5 INT := 0;
	notas2 INT := 0;
	moedas1 INT := 0;
BEGIN
	notas200 := troco / 200;
	notas100 := troco % 200 / 100;
	notas50 := troco % 200 % 100 / 50;
	notas20 := troco % 200 % 100 % 50 / 20;
	notas10 := troco % 200 % 100 % 50 % 20 / 10;
	notas5 := troco % 200 % 100 % 50 % 20 % 10 / 5;
	notas2 := troco % 200 % 100 % 50 % 20 % 10 % 5 / 2;
	moedas1 := troco % 200 % 100 % 50 % 20 % 10 % 5 % 2;
	resultado := concat (
		-- E é de escape. Para que \n tenha sentido
		-- || operador de concatenação
		'Notas de 200: ',
		notas200 || E'\n',
		'Notas de 100: ',
		notas100 || E'\n',
		'Notas de 50: ',
		notas50 || E'\n',
		'Notas de 20: ',
		notas20 || E'\n',
		'Notas de 10: ',
		notas10 || E'\n',
		'Notas de 5: ',
		notas5 || E'\n',
		'Notas de 2: ',
		notas2 || E'\n',
		'Moedas de 1: ',
		moedas1 || E'\n'
	);
END;
$$

DO
$$
DECLARE
	resultado VARCHAR(500);
	troco INT := 43;
BEGIN
	CALL sp_obter_notas_para_compor_o_troco (resultado, troco);
	RAISE NOTICE '%', resultado;
END;
$$

-- Ex1.1
-- Gerando tabela Log
CREATE TABLE tb_log (
    id_log SERIAL PRIMARY KEY,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    procedimento VARCHAR(100) NOT NULL,
    mensagem VARCHAR(500)
);

-- Ajuste de cadastro de clientes 
CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente (IN nome VARCHAR(200), IN codigo INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
BEGIN
    IF codigo IS NULL THEN
        INSERT INTO tb_cliente (nome) VALUES (nome);
        INSERT INTO tb_log (procedimento, mensagem)
        VALUES ('sp_cadastrar_cliente', CONCAT('Cliente "', nome, '" cadastrado com sucesso.'));
    ELSE
        INSERT INTO tb_cliente (cod_cliente, nome) VALUES (codigo, nome);
        INSERT INTO tb_log (procedimento, mensagem)
        VALUES ('sp_cadastrar_cliente', CONCAT('Cliente "', nome, '" com código ', codigo, ' cadastrado.'));
    END IF;
END;
$$;

-- Ajustando pedido e registrando no Log 
CREATE OR REPLACE PROCEDURE sp_criar_pedido (OUT cod_pedido INT, cod_cliente INT)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO tb_pedido (cod_cliente) VALUES (cod_cliente);
    SELECT LASTVAL() INTO cod_pedido;

    INSERT INTO tb_log (procedimento, mensagem)
    VALUES ('sp_criar_pedido', CONCAT('Pedido criado para o cliente ', cod_cliente, ' com código ', cod_pedido, '.'));
END;
$$;

-- Ajustando 'adicionar item ao pedido' para registro de Log
CREATE OR REPLACE PROCEDURE sp_adicionar_item_a_pedido (IN cod_item INT, IN cod_pedido INT)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO tb_item_pedido (cod_item, cod_pedido) VALUES (cod_item, cod_pedido);
    UPDATE tb_pedido SET data_modificacao = CURRENT_TIMESTAMP WHERE cod_pedido = cod_pedido;

    INSERT INTO tb_log (procedimento, mensagem)
    VALUES ('sp_adicionar_item_a_pedido', CONCAT('Item ', cod_item, ' adicionado ao pedido ', cod_pedido, '.'));
END;
$$;

-- Ajustando 'calcular valor do pedido' no Log
DROP PROCEDURE IF EXISTS sp_calcular_valor_de_um_pedido(INTEGER);

CREATE OR REPLACE PROCEDURE sp_calcular_valor_de_um_pedido (IN p_cod_pedido INT, OUT valor_total NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Calculando total
    SELECT SUM(i.valor)
    INTO valor_total
    FROM tb_pedido p
    INNER JOIN tb_item_pedido ip ON p.cod_pedido = ip.cod_pedido
    INNER JOIN tb_item i ON i.cod_item = ip.cod_item
    WHERE p.cod_pedido = p_cod_pedido;

    -- Registrando log
    INSERT INTO tb_log (procedimento, mensagem)
    VALUES (
        'sp_calcular_valor_de_um_pedido',
        CONCAT('Valor do pedido ', p_cod_pedido, ' calculado: R$ ', valor_total)
    );
END;
$$;

-- Ajustando 'fechar pedido' no Log
CREATE OR REPLACE PROCEDURE sp_fechar_pedido (IN valor_a_pagar INT, IN cod_pedido INT)
LANGUAGE plpgsql
AS $$
DECLARE
    valor_total NUMERIC;
BEGIN
    CALL sp_calcular_valor_de_um_pedido (cod_pedido, valor_total);

    IF valor_a_pagar < valor_total THEN
        RAISE 'Valor insuficiente: R$% para pagar R$%', valor_a_pagar, valor_total;
    ELSE
        UPDATE tb_pedido
        SET data_modificacao = CURRENT_TIMESTAMP,
            status = 'fechado'
        WHERE cod_pedido = cod_pedido;

        INSERT INTO tb_log (procedimento, mensagem)
        VALUES ('sp_fechar_pedido', CONCAT('Pedido ', cod_pedido, ' fechado com sucesso.'));
    END IF;
END;
$$;

-- Ajustando 'obter notas para compor troco' no Log
CREATE OR REPLACE PROCEDURE sp_obter_notas_para_compor_o_troco (OUT resultado VARCHAR(500), IN troco INT)
LANGUAGE plpgsql
AS $$
DECLARE
    notas200 INT := 0;
    notas100 INT := 0;
    notas50 INT := 0;
    notas20 INT := 0;
    notas10 INT := 0;
    notas5 INT := 0;
    notas2 INT := 0;
    moedas1 INT := 0;
BEGIN
    notas200 := troco / 200;
    notas100 := troco % 200 / 100;
    notas50 := troco % 200 % 100 / 50;
    notas20 := troco % 200 % 100 % 50 / 20;
    notas10 := troco % 200 % 100 % 50 % 20 / 10;
    notas5 := troco % 200 % 100 % 50 % 20 % 10 / 5;
    notas2 := troco % 200 % 100 % 50 % 20 % 10 % 5 / 2;
    moedas1 := troco % 200 % 100 % 50 % 20 % 10 % 5 % 2;

    resultado := concat(
        'Notas de 200: ', notas200, E'\n',
        'Notas de 100: ', notas100, E'\n',
        'Notas de 50: ', notas50, E'\n',
        'Notas de 20: ', notas20, E'\n',
        'Notas de 10: ', notas10, E'\n',
        'Notas de 5: ', notas5, E'\n',
        'Notas de 2: ', notas2, E'\n',
        'Moedas de 1: ', moedas1
    );

    INSERT INTO tb_log (procedimento, mensagem)
    VALUES ('sp_obter_notas_para_compor_o_troco', CONCAT('Troco calculado: ', troco, ' detalhado como:', resultado));
END;
$$;

-- Verificação
SELECT * FROM tb_log ORDER BY data_hora DESC;


-- Ex1.2
-- Criando proced para 'contar pedidos por cliente'
CREATE OR REPLACE PROCEDURE sp_contar_pedidos_por_cliente (IN cod_cliente INT)
LANGUAGE plpgsql
AS $$
DECLARE
    total_pedidos INT;
BEGIN
    -- Cálculo de pedidos do cliente
    SELECT COUNT(*)
    INTO total_pedidos
    FROM tb_pedido
    WHERE cod_cliente = cod_cliente;

    -- Resultado
    RAISE NOTICE 'O cliente % possui % pedido(s) no total.', cod_cliente, total_pedidos;

    -- Alternativa: Registrar no log
    INSERT INTO tb_log (procedimento, mensagem)
    VALUES (
        'sp_contar_pedidos_por_cliente',
        CONCAT('Cliente ', cod_cliente, ' possui ', total_pedidos, ' pedido(s).')
    );
END;
$$;
-- Verificando
SELECT * FROM tb_log ORDER BY data_hora DESC;

-- Ex1.3
-- Criando o proced e adicionando parâmetro
DROP PROCEDURE sp_contar_pedidos_por_cliente(integer)

CREATE OR REPLACE PROCEDURE sp_contar_pedidos_por_cliente (
    IN cod_cliente INT,
    OUT total_pedidos INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Contagem
    SELECT COUNT(*)
    INTO total_pedidos
    FROM tb_pedido
    WHERE cod_cliente = cod_cliente;

    -- Criação de registro no log
    INSERT INTO tb_log (procedimento, mensagem)
    VALUES (
        'sp_contar_pedidos_por_cliente',
        CONCAT('Cliente ', cod_cliente, ' possui ', total_pedidos, ' pedido(s).')
    );
END;
$$;

-- Ex1.4 
-- Criando o procedimento solicitado na tarefa
CREATE OR REPLACE PROCEDURE sp_contar_pedidos_inout (
    INOUT cod_cliente INT 
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_pedidos INT;
BEGIN
    -- Contando total pedidos
    SELECT COUNT(*)
    INTO total_pedidos
    FROM tb_pedido
    WHERE cod_cliente = cod_cliente;

    -- Atualizando parâmetro INOUT de acordo com o total de pedidos
    cod_cliente := total_pedidos;

    -- Registrando
    INSERT INTO tb_log (procedimento, mensagem)
    VALUES (
        'sp_contar_pedidos_inout',
        CONCAT('Cliente com código ', cod_cliente, ' possui ', total_pedidos, ' pedido(s).')
    );
END;
$$;

-- Ex1.5
-- Elborando procedimento
CREATE OR REPLACE PROCEDURE sp_cadastrar_varios_clientes (
    OUT mensagem TEXT,      
    VARIADIC nomes TEXT[]    
)
LANGUAGE plpgsql
AS $$
DECLARE
    nome TEXT; 
BEGIN
    FOR nome IN SELECT unnest(nomes)
    LOOP
        INSERT INTO tb_cliente (nome) VALUES (nome);
    END LOOP;

    -- Msg
    mensagem := CONCAT(
        'Os clientes: ',
        array_to_string(nomes, ', '),
        ' foram cadastrados.'
    );

    INSERT INTO tb_log (procedimento, mensagem)
    VALUES ('sp_cadastrar_varios_clientes', mensagem);
END;
$$;

-- Ex1.6
-- Criação dos blocos anônimos para cada proced criado
-- Cadastro vários clientes e retornando uma mensagem com os respectivos nomes
DO $$
DECLARE
    resultado TEXT; 
BEGIN
    CALL sp_cadastrar_varios_clientes(resultado, 'João da Silva', 'Maria Santos', 'Manuel Campos');
    RAISE NOTICE '%', resultado; 
END;
$$;

-- Somatório pedidos por cliente
DROP PROCEDURE IF EXISTS sp_contar_pedidos_por_cliente(cod_cliente INT, OUT total INT);

CREATE OR REPLACE FUNCTION sp_contar_pedidos_por_cliente(cod_cliente INT) RETURNS INT AS $$
DECLARE
    total INT;
BEGIN
    SELECT COUNT(*) INTO total
    FROM pedidos
    WHERE pedidos.cod_cliente = cod_cliente;
    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT table_name
FROM information_schema.tables
WHERE table_name = 'pedidos';

SET search_path TO public;

CREATE OR REPLACE FUNCTION sp_contar_pedidos_por_cliente(cod_cliente INT) RETURNS INT AS $$
DECLARE
    total INT;
BEGIN
    SELECT COUNT(*) INTO total
    FROM pedidos
    WHERE pedidos.cod_cliente = cod_cliente;
    RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Recebendo e retornando o total de pedidos realizados por um cliente usando 'INOUT'
CREATE OR REPLACE PROCEDURE sp_contar_pedidos_por_cliente_inout(
    cod_cliente INT,    
    INOUT total INT     
) AS $$
BEGIN
    SELECT COUNT(*)
    INTO total
    FROM pedidos
    WHERE pedidos.cod_cliente = cod_cliente;
END;
$$ LANGUAGE plpgsql;

-- Criando pedido para um cliente
DO $$
DECLARE
    novo_pedido INT; 
    cod_cliente INT := 1; 
BEGIN
    CALL sp_criar_pedido(novo_pedido, cod_cliente);
    RAISE NOTICE 'Pedido criado com sucesso! Código do pedido: %', novo_pedido;
END;
$$;

-- Adicionando item_a_pedido
DROP FUNCTION IF EXISTS sp_adicionar_item_a_pedido(INT, INT);

CREATE OR REPLACE PROCEDURE sp_adicionar_item_a_pedido(cod_pedido INT, cod_item INT) AS $$
BEGIN
    INSERT INTO itens_pedido (cod_pedido, cod_item)
    VALUES (cod_pedido, cod_item);
END;
$$ LANGUAGE plpgsql;

-- Calculando o valor total de um pedido
DO $$
DECLARE
    valor_total NUMERIC; 
BEGIN
    CALL sp_calcular_valor_de_um_pedido(1, valor_total); 
    RAISE NOTICE 'O valor total do pedido é: R$ %.2f', valor_total;
END;
$$;

-- Fechando pedido
DROP PROCEDURE sp_fechar_pedido(integer,integer)

CREATE OR REPLACE PROCEDURE sp_fechar_pedido(p_cod_pedido INT, p_cod_usuario INT) AS $$
BEGIN
    UPDATE pedidos
    SET status = 'Fechado', atualizado_por = p_cod_usuario
    WHERE pedidos.cod_pedido = p_cod_pedido;
    
    RAISE NOTICE 'Pedido % foi fechado pelo usuário %', p_cod_pedido, p_cod_usuario;
END;
$$ LANGUAGE plpgsql;

-- Calculando troco
DROP PROCEDURE sp_calcular_troco(integer,integer) 

CREATE OR REPLACE PROCEDURE sp_calcular_troco(
    OUT troco NUMERIC,
    valor_pago INTEGER,
    valor_total INTEGER
) AS $$
BEGIN
    troco := valor_pago - valor_total;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    troco NUMERIC; 
BEGIN
    CALL sp_calcular_troco(troco, 100, 65); 
    RAISE NOTICE 'O troco é: %', troco;     
END;
$$;

-- Obtendo a composição de notas para a realização de um troco
CREATE OR REPLACE PROCEDURE sp_calcular_troco(
    OUT resultado NUMERIC,  
    valor_pago NUMERIC,     
    valor_total NUMERIC     
) AS $$
BEGIN
    resultado := valor_pago - valor_total;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    resultado NUMERIC;  
BEGIN
    CALL sp_calcular_troco(resultado, 100::NUMERIC, 65::NUMERIC);  
    RAISE NOTICE 'O troco é: %', resultado;
END;
$$;