# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
