-- Teste de Envio PL/SQL
begin
apex_mail.send(
    p_from=> 'from@mail.com',
    p_to=> 'to@mail.com.br',
    p_subj => 'Mensagem de Teste',
    p_body => 'Esta é uma mensagem de teste.'
);

apex_mail.push_queue();
end;

-- Envio email template
declare
        data_venda varchar2(20);
        itens_json varchar2(4000);
        total_venda varchar2(100);
        venda vw_venda%ROWTYPE;
begin
    select * into venda from vw_venda where id = :P16_ID;

    data_venda := to_char(venda.data_venda, 'DD/MM/YYYY');
    total_venda := to_char(venda.total_venda,'FML999G999G999G999G990D00');

    SELECT 
        LISTAGG(vd.produto||';'||vd.qtd||';'||TO_CHAR(vd.total_item,'FML999G999G999G999G990D00'), ':') 
        WITHIN GROUP (ORDER BY vd.item_id)
    into Itens_json
    FROM vw_detalhes_venda vd
    WHERE vd.venda_id = venda.id;
    
    apex_mail.send (			
        p_to                 => 'to@gmail.com',
        p_from				 => 'from@email.com',
        p_template_static_id => 'ORDER',
        p_placeholders       => '{' ||
        '    "ORDER_NUMBER":'            || apex_json.stringify( venda.id ) ||
        '   ,"CUSTOMER_NAME":'           || apex_json.stringify( venda.nome ) ||
        '   ,"ORDER_DATE":'              || apex_json.stringify( data_venda ) ||
        '   ,"ITEMS_ORDERED":'           || apex_json.stringify( itens_json ) ||
        '   ,"ORDER_TOTAL":'             || apex_json.stringify( total_venda ) ||
        '   ,"MY_APPLICATION_LINK":'     || apex_json.stringify( apex_mail.get_instance_url || apex_page.get_url( 16 )) ||
        '}' );
    APEX_MAIL.push_queue();
    exception
     when others
        then apex_error.add_error (
                        p_message          => 'Erro ao enviar e-mail!',
                        p_display_location => apex_error.c_inline_in_notification );
end;


-- Envio com anexo from arquivos do app (APEX_APPLICATION_FILES)
DECLARE
    l_id NUMBER;
BEGIN
    l_id := APEX_MAIL.SEND(
        p_to        => 'to@gmail.com',
        p_from	    => 'from@email.com.br',
        p_subj      => 'APEX_MAIL com anexo',
        p_body      => 'Por favor veja o anexo.',
        p_body_html => '<b>Por favor</b> veja o anexo');
    FOR c1 IN (SELECT filename, blob_content, mime_type 
        FROM APEX_APPLICATION_FILES
        WHERE ID IN (46425908370989844322)) LOOP

        APEX_MAIL.ADD_ATTACHMENT(
            p_mail_id    => l_id,
            p_attachment => c1.blob_content,
            p_filename   => c1.filename,
            p_mime_type  => c1.mime_type);
        END LOOP;
        APEX_MAIL.push_queue();
    exception
     when others
        then apex_error.add_error (
                        p_message          => 'Erro ao enviar e-mail!',
                        p_display_location => apex_error.c_inline_in_notification );
END;

-- Criar Função para gerar CSV em memória com dados de uma tabela
create or replace function func_table_to_csv( p_tname in varchar2 )
 return clob
 is
    l_output        clob;
    l_theCursor     integer default dbms_sql.open_cursor;
    l_columnValue   varchar2(4000);
    l_status        integer;
    l_query         varchar2(1000)
                    default 'select * from ' || p_tname;
    l_colCnt        number := 0;
    l_separator     varchar2(1);
    l_descTbl       dbms_sql.desc_tab;
begin
    dbms_lob.createtemporary(l_output, true);  -- Initialize the CLOB
    execute immediate 'alter session set nls_date_format=''dd-mon-yyyy hh24:mi:ss'' ';
    dbms_sql.parse(  l_theCursor,  l_query, dbms_sql.native );
    dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
     for i in 1 .. l_colCnt loop
       dbms_lob.writeappend(l_output, length(l_separator || '"' || l_descTbl(i).col_name|| '"'), l_separator || '"' || l_descTbl(i).col_name|| '"');
       dbms_sql.define_column( l_theCursor, i, l_columnValue, 4000 );
       l_separator := ',';
    end loop;
    dbms_lob.writeappend(l_output, length(chr(10)), chr(10));
    l_status := dbms_sql.execute(l_theCursor);
     while ( dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
        l_separator := '';
        for i in 1 .. l_colCnt loop
            dbms_sql.column_value( l_theCursor, i, l_columnValue );
            dbms_lob.writeappend(l_output, length(l_separator || l_columnValue), l_separator || l_columnValue);
            l_separator := ',';
        end loop;
        dbms_lob.writeappend(l_output, length(chr(10)), chr(10));
    end loop;
    dbms_sql.close_cursor(l_theCursor);
    execute immediate 'alter session set nls_date_format=''dd-MON-yy'' ';
    --dbms_lob.freetemporary(l_output);  -- Free the temporary LOB
    return l_output;
exception
   when others then
        execute immediate 'alter session set nls_date_format=''dd-MON-yy'' ';
        dbms_lob.freetemporary(l_output);  -- Free the temporary LOB in case of an exception
        raise;
end;
/ 

-- Envio de Anexo CSV
DECLARE
    l_id NUMBER;
    l_clob clob;
BEGIN
    l_id := APEX_MAIL.SEND(
        p_to        => 'to@mail.com.br',
        p_from      => 'from@mail.com',
        p_subj      => 'Backup da tabela em anexo',
        p_body      => 'Ver o anexo.',
        p_body_html => '<b>Por favor</b> Ver o anexo.');

        l_clob := func_table_to_csv(p_tname => 'NOME_DA_TABELA')

        APEX_MAIL.ADD_ATTACHMENT(
			p_mail_id    => l_id,
			p_attachment => l_clob,
			p_filename   => 'nome_do_arquivo.csv',
			p_mime_type  => 'text/csv');
    
    apex_mail.push_queue();
	
	dbms_lob.freetemporary(l_clob);
END;

-- Análise dos logs
Select * from apex_mail_log where mail_send_error is not null;
-- Análise da fila de emails

SELECT * FROM APEX_MAIL_QUEUE where trunc(mail_message_created) = trunc(sysdate);

