import os
import csv
from datetime import datetime, timedelta
import sys

from gpstime import UTCFromGps


def munge_data(rowdict, gps_week=1770):
    newdict = {key: float(val) for key, val in rowdict.items()}
    # convert time of week to a datetime
    time_of_week = newdict['TOW']
    time_of_week /= 1000.0
    if not time_of_week:
        return None
    (year, month, day, hh, mm, ss) = UTCFromGps(gps_week, time_of_week)
    ms = int((ss % 1) * 1e6)
    ss = int(ss)
    newdict['UTC'] = datetime(year, month, day, hh, mm, ss, ms)
    # fix decimal places in lat/lon
    try:
        # generally if we have TOW we have GPS coords but not if we don't have enough sats
        newdict['LON'] /= 1e7
        newdict['LAT'] /= 1e7
        # YAW and MGH are both -180/+180 but COG is 0-360
        newdict['COG_180'] = newdict['COG'] if newdict['COG'] < 180 else 180 - newdict['COG']
    except KeyError:
        pass
    return newdict


def process(infile):
    rows = []
    columns = set()

    for line in open(infile, 'rU'):
        line = line.lstrip('!')
        line = line.rstrip('\n*')
        try:
            data = dict([keyval.split(':') for keyval in line.split(',')])
            if not 'VER' in data:
                continue
            data = munge_data(data)
            if data:
                columns |= set(data.keys())
                rows.append(data)
        except ValueError:
            # bad line
            continue

    base, ext = os.path.splitext(infile)
    outfile = "%s.clean.csv" % base
    dw = csv.DictWriter(open(outfile, 'wb'), sorted(columns))
    dw.writeheader()
    for rowdict in rows:
        dw.writerow(rowdict)


def main():
    filename = sys.argv[1]
    process(filename)


if __name__ == '__main__':
    main()