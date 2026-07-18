import pandas as pd
import logging

def load_returns(connection):
    returns_df = pd.read_excel('data/raw/raw_data.xlsx',sheet_name='Returns')
    returns_df.columns=['returned','order_id']
    returns_df= returns_df.astype(object).where(pd.notnull(returns_df),None)
    cursor = connection.cursor()
    cursor.execute('TRUNCATE TABLE bronze.returns_order;')
    connection.commit()
    logging.info('bronze.returns_order table truncated')

    data_rows = list(returns_df.itertuples(index=False, name=None))
    insert_sql = 'INSERT INTO bronze.returns_order VALUES(?,?)'

    cursor.executemany(insert_sql,data_rows)
    connection.commit()
    logging.info(f'inserted {len(returns_df)} rows into bronze.returns_order')