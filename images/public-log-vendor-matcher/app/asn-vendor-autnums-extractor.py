#!/usr/bin/env python3
from bs4 import BeautifulSoup
import sys

autnums = sys.argv[1]
outputCsvFile = sys.argv[2]

with open(autnums, 'r') as input_file:
    contents = input_file.read()
    soup = BeautifulSoup(contents, 'lxml')
#    printn(soup.a)
for tag in soup.find_all('a'):
    asnNum = str(f'{tag.text}').strip()
    asnNextSibling = str(f'{tag.next_sibling}').strip()
    asnNextSibling = asnNextSibling.replace(',', '')
    asn = (f'{asnNum},{asnNextSibling}')
    # print(asn)
    results_file = open(outputCsvFile, "a")
    results_file.write(asn)
    results_file.write("\n")
    results_file.close()
input_file.close()
