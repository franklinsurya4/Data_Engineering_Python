from pyspark.sql.functions import col, trim, upper

# Standardize column
def standardize_column(df, column_name):

    return df.withColumn(
        column_name,
        upper(trim(col(column_name)))
    )

# Remove duplicate records
def remove_duplicates(df):

    return df.dropDuplicates()