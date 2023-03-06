import csv
from db_connect import connect, create_cursor, close_connection
from xml.etree.ElementTree import fromstring, ElementTree
from statistics import mean

with open('./data/Match.csv') as csv_file:
    connection = connect('db_connection', 'localhost',
                         'postgres', 'admin', '5432')
    cursor = create_cursor(connection)

    csv_reader = csv.reader(csv_file, delimiter=',')
    query = 'INSERT INTO possession (match_api_id, home_possession, away_possession)'
    inserts = []
    for row in csv_reader:
        if (len(row[84]) > 10):
            tree = ElementTree(fromstring(str(row[84])))
            root = tree.getroot()
            home_possession = []
            away_possession = []
            for x in root.findall('value'):
                try:
                    awaypos = float(x.find('awaypos').text)
                    homepos = float(x.find('homepos').text)
                    home_possession.append(homepos)
                    away_possession.append(awaypos)
                except:
                    pass
            try:
                home_possession = mean(home_possession)
                away_possession = mean(away_possession)
                inserts.append('({0}, {1}, {2})'.format(
                    row[6], home_possession, away_possession))
            except:
                pass

    query += ' VALUES ' + ', '.join(inserts)
    print(query)
    cursor.execute(query)
    connection.commit()
    close_connection(connection)
