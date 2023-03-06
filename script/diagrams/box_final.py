import matplotlib.pyplot as plt
import csv


def my_plot(row):
    stats = [{
        "label": 'stddev: {}, asimetría: {}'.format(row[3], row[10]),
        "mean":  float(row[2]),
        "med": float(row[7]),
        "q1": float(row[8]),
        "q3": float(row[9]),
        "whislo": float(row[4]),
        "whishi": float(row[5]),
        "fliers": []
    }]
    fs = 10
    fig, axes = plt.subplots(
        nrows=1, ncols=1, figsize=(6, 6), sharey=True)
    axes.bxp(stats)
    axes.set_ylabel('Puntos', fontsize=fs)
    axes.set_title(
        '{} ({} Equipos)'.format(row[0], row[1]), fontsize=fs)
    plt.show()


with open('./dispersion_measures.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    line_count = 0
    for row in csv_reader:
        if line_count == 0:
            print(f'Column names are {", ".join(row)}\n')
            line_count += 1
        else:
            my_plot(row)
            line_count += 1
    print(f'\nProcessed {line_count} lines.')
