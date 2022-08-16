-- function signature (PostgreSQL 10)
-- Igor Wandermurem Dummer - 2019109389
-- Rogério Medeiros dos Santos júnior - 2019109261
CREATE OR REPLACE FUNCTION testeEquivalenciaPorConflito () 
RETURNS integer AS $$
	DECLARE
	 	resultado int; -- variavel para armazenar o resultado
    BEGIN	
		DROP TABLE IF EXISTS public.arestas;
			-- tabela que representa as arestas do grafo
    	CREATE TABLE arestas(no1 int, no2 int,valor char);
		DROP TABLE IF EXISTS public.vertice;
			-- tabela que representa os vertices do grafo
    	CREATE TABLE vertice(nome int, visitado int, concluido int);
    -- identifica as arestas e armazena na tabela Schedule
		INSERT INTO arestas SELECT distinct tb1."#t" as no1, tb2."#t" as no2, tb1."attr" as valor 
			FROM "Schedule" as tb1 cross join "Schedule" as tb2 
			where tb1."attr" = tb2."attr" 
			and tb1."#t" != tb2."#t" 
			and tb1."time" < tb2."time"
			and ((tb1."op" = 'W' and tb2."op" = 'R') 
				or (tb1."op" = 'R' and tb2."op" = 'W') 
				or (tb1."op" = 'w' and tb2."op" = 'w')) ; -- condição para que ocorra conflito
		INSERT INTO vertice SELECT DISTINCT "#t" from "Schedule"; -- pega os vertices da tabela Schedule
		resultado := DFS_dirigido(); -- chama a função para encontrar ciclo e armazena em resultado
		DROP TABLE IF EXISTS public.vertice;
		DROP TABLE IF EXISTS public.arestas;
		if( resultado = 1 ) then -- retorna o resultado da função. 1 para caso não haja ciclo, 0 para caso haja
			return 0;
		end if;
		return 1; 
    END;
$$ LANGUAGE plpgsql;

-- utilizamos o algoritmo do DFS para encontrar o ciclo no grafo, ele visita todos os vértices e percorre
-- as arestas, analisando os vertices vizinhos
CREATE OR REPLACE FUNCTION DFS_dirigido() 
RETURNS int AS $$
	DECLARE
	f record;
	lixo integer;
	BEGIN
		-- popula os visitados com 0, inicialmente
		lixo:= zeraVisitados() ; 
		-- percorre cada vertice do grafo
		for f in (SELECT * FROM public."vertice") loop
			if(f.visitado = 0) then -- caso o vertice nao tenha sido visitado ainda
				if(DFS(f.nome) = 1) then -- caso a dfs tenha encontrado ciclo, retorna 1
					return 1;
				end if;
			end if;
		end loop;
		return 0; -- caso não tenha encontrado ciclo
	END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION DFS (nomeV int) 
RETURNS int as $$
	DECLARE 
	f record;
	i record;
	v record;
	BEGIN
		-- seleciona o vertice a ser analisado
		SELECT * INTO f FROM public."vertice" WHERE nome = nomeV;
		-- define o vertice como visitado
		UPDATE public."vertice" SET visitado = 1 where nome = f.nome;
		-- percorre cada aresta do vertice
		for i in (SELECT * FROM public."arestas" WHERE no1 = f.nome) loop
			-- analisa o vertice vizinho
			SELECT * INTO v FROM public."vertice" WHERE i.no2 = nome;
			-- caso o vertice tenha sido visitado e nao tenha sido concluido, ou seja, 
			-- encontrado um loop, significa que existe um ciclo
			if(v.visitado = 1) then
				if(v.concluido = 0) then
					return 1;
				end if;
			else
				if(DFS(v.nome) = 1) then -- chama o dfs recursivamente pro vertice vizinho
					return 1;
				end if;
			end if;
		end loop;
		-- define que foi percorrido a partir do vertice
		UPDATE public."vertice" SET concluido = 1 where nome = f.nome;
		return 0; -- nao encontrou um ciclo
	END;
$$ LANGUAGE plpgsql;

-- zera os campos visitado e concluido da tabela de vertices
CREATE OR REPLACE FUNCTION zeraVisitados ()
RETURNS integer AS $$
	begin
	update vertice set visitado = 0,concluido = 0 ;
	return 1;
	END;
$$ LANGUAGE plpgsql;

-- chama a função
SELECT testeEquivalenciaPorConflito() AS resp;