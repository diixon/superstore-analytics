import pandas as pd
import logging

def load_people(connection):
    people_df=pd.read_excel('data/raw/raw_data.xlsx',sheet_name='People')
    people_df.columns=['person_name','region']
    people_df=people_df.astype(object).where(pd.notnull(people_df), None)

    cursor = connection.cursor()
    cursor.execute('TRUNCATE TABLE bronze.people;')
    connection.commit()
    logging.info('bronze.people table truncated')
    insert_sql = 'INSERT INTO bronze.people(person_name, region) VALUES (?, ?);'
    data_rows = list(people_df.itertuples(index=False,name=None))
    cursor.executemany(insert_sql, data_rows)
    connection.commit()
    logging.info(f'Inserted {len(people_df)} rows into bronze.people')


