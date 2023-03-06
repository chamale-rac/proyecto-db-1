import csv
from db_connect import connect, create_cursor, close_connection
from xml.etree.ElementTree import fromstring, ElementTree

with open('./data/Match.csv') as csv_file:
    connection = connect('db_connection', 'localhost',
                         'postgres', 'admin', '5432')
    cursor = create_cursor(connection)

    csv_reader = csv.reader(csv_file, delimiter=',')
    query = 'INSERT INTO goals (match_api_id, team_api_id, minute)'
    inserts = []
    for row in csv_reader:
        if (len(row[77]) > 10):
            tree = ElementTree(fromstring(str(row[77])))
            root = tree.getroot()
            goals = []
            for x in root.findall('value'):
                try:
                    team = x.find('team')
                    if (team.text == str(row[7])):
                        goals.append('({0}, {1}, {2})'.format(
                            row[6], row[7], x.find('elapsed').text))
                    else:
                        goals.append('({0}, {1}, {2})'.format(
                            row[6], row[8], x.find('elapsed').text))
                except:
                    pass
            for goal in goals:
                inserts.append(goal)

    query += ' VALUES ' + ', '.join(inserts)
    print(query)
    cursor.execute(query)
    connection.commit()
    close_connection(connection)
