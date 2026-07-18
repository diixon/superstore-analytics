import logging

def run_silver_layer(connection):
    cursor=connection.cursor()
    cursor.execute("EXEC silver.usp_LoadSilverLayer;")
    connection.commit()
    logging.info('Silver layer procedure executed successfully.') 

def run_gold_layer(connection):
    cursor=connection.cursor()
    cursor.execute('EXEC gold.usp_LoadGoldLayer;')
    connection.commit()
    logging.info(("Gold layer procedure executed successfully."))


