import pandas as pd

print(pd.__version__)

xlsx_file = pd.ExcelFile('data/raw/raw_data.xlsx')
print(xlsx_file.sheet_names)

people_df = pd.read_excel(xlsx_file,sheet_name='People')
print(people_df)
print(people_df.shape)
print(people_df.dtypes)

orders_df=pd.read_excel(xlsx_file,sheet_name='Orders')
print(orders_df.shape)
#print(orders_df)
print(orders_df.dtypes)
print(orders_df.head())

returns_df=pd.read_excel(xlsx_file,sheet_name='Returns')
print(returns_df.head())
print(returns_df.dtypes)
print(returns_df.shape)
