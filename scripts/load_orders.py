import pandas as pd
import logging

def load_orders(connection):
    orders_df = pd.read_excel('data/raw/raw_data.xlsx',sheet_name='Orders')

    orders_df.columns = [
     "row_id", "order_id", "order_date", "ship_date", "ship_mode",
     "customer_id", "customer_name", "segment", "country_region",
      "city", "state", "postal_code", "region", "product_id",
      "category", "sub_category", "product_name",
      "sales", "quantity", "discount", "profit",
    ]
    orders_df = orders_df.astype(object).where(pd.notnull(orders_df),None)

    cursor= connection.cursor()
    cursor.execute('TRUNCATE TABLE bronze.orders;')
    connection.commit()
    logging.info('bronze.orders table truncated')

    insert_sql = """
        INSERT INTO bronze.orders (
            row_id, order_id, order_date, ship_date, ship_mode,
            customer_id, customer_name, segment, country_region,
            city, state, postal_code, region, product_id,
            category, sub_category, product_name,
            sales, quantity, discount, profit
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
    """

    data_rows = list(orders_df.itertuples(index=False, name=None)) 
    cursor.executemany(insert_sql,data_rows)
    connection.commit()
 
    logging.info(f'inserted {len(orders_df)} rows into bronze.orders')


