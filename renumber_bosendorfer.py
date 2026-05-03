#!/usr/bin/env python3
"""
Extract and renumber Bosendorfer f-tables from ball11.csd for insertion into ball9.csd
Maps old ftable numbers to new ones to avoid conflicts with existing instruments.
"""

import re

# Renumbering map: old_ftable -> new_ftable
# Ranges with gap spaces for future expansion:
# emp25: 1234-1274 (includes boundary 645->1274)  [gap 1275]
# emp31: 1276-1329 (includes boundary 700->1329)  [gap 1376-1384]
# emp39: 1330-1375 (includes boundaries 745->1374, 746->1375)
# emp47: 1385-1439 (includes boundary 801->1439)  [gap 1440]
# emp63: 1440-1494 (includes boundary 857->1495)  [gap 1495]
# emp78: 1496-1550 (includes boundary 912->1550)  [gap 1551]
# emp85: 1551-1606

RENUMBER_MAP = {
    # emp25 samples 605-644 + boundary 645
    605: 1234, 606: 1235, 607: 1236, 608: 1237, 609: 1238, 610: 1239, 611: 1240, 612: 1241, 613: 1242, 614: 1243,
    615: 1244, 616: 1245, 617: 1246, 618: 1247, 619: 1248, 620: 1249, 621: 1250, 622: 1251, 623: 1252, 624: 1253,
    625: 1254, 626: 1255, 627: 1256, 628: 1257, 629: 1258, 630: 1259, 631: 1260, 632: 1261, 633: 1262, 634: 1263,
    635: 1264, 636: 1265, 637: 1266, 638: 1267, 639: 1268, 640: 1269, 641: 1270, 642: 1271, 643: 1272, 644: 1273, 645: 1274,

    # emp25 metadata
    601: 1230, 602: 1231, 603: 1232, 604: 1233,

    # emp31 samples 650-699 + boundary 700
    650: 1276, 651: 1277, 652: 1278, 653: 1279, 654: 1280, 655: 1281, 656: 1282, 657: 1283, 658: 1284, 659: 1285,
    660: 1286, 661: 1287, 662: 1288, 663: 1289, 664: 1290, 665: 1291, 666: 1292, 667: 1293, 668: 1294, 669: 1295,
    670: 1296, 671: 1297, 672: 1298, 673: 1299, 674: 1300, 675: 1301, 676: 1302, 677: 1303, 678: 1304, 679: 1305,
    680: 1306, 681: 1307, 682: 1308, 683: 1309, 684: 1310, 685: 1311, 686: 1312, 687: 1313, 688: 1314, 689: 1315,
    690: 1316, 691: 1317, 692: 1318, 693: 1319, 694: 1320, 695: 1321, 696: 1322, 697: 1323, 698: 1324, 699: 1325, 700: 1326,

    # emp31 metadata
    646: 1322, 647: 1323, 648: 1324, 649: 1325,

    # emp39 samples 705-744 + boundaries 745-746
    705: 1330, 706: 1331, 707: 1332, 708: 1333, 709: 1334, 710: 1335, 711: 1336, 712: 1337, 713: 1338, 714: 1339,
    715: 1340, 716: 1341, 717: 1342, 718: 1343, 719: 1344, 720: 1345, 721: 1346, 722: 1347, 723: 1348, 724: 1349,
    725: 1350, 726: 1351, 727: 1352, 728: 1353, 729: 1354, 730: 1355, 731: 1356, 732: 1357, 733: 1358, 734: 1359,
    735: 1360, 736: 1361, 737: 1362, 738: 1363, 739: 1364, 740: 1365, 741: 1366, 742: 1367, 743: 1368, 744: 1369,
    745: 1370, 746: 1371,

    # emp39 metadata
    701: 1326, 702: 1327, 703: 1328, 704: 1329,

    # emp47 samples 751-800 + boundary 801
    751: 1375, 752: 1376, 753: 1377, 754: 1378, 755: 1379, 756: 1380, 757: 1381, 758: 1382, 759: 1383, 760: 1384,
    761: 1385, 762: 1386, 763: 1387, 764: 1388, 765: 1389, 766: 1390, 767: 1391, 768: 1392, 769: 1393, 770: 1394,
    771: 1395, 772: 1396, 773: 1397, 774: 1398, 775: 1399, 776: 1400, 777: 1401, 778: 1402, 779: 1403, 780: 1404,
    781: 1405, 782: 1406, 783: 1407, 784: 1408, 785: 1409, 786: 1410, 787: 1411, 788: 1412, 789: 1413, 790: 1414,
    791: 1415, 792: 1416, 793: 1417, 794: 1418, 795: 1419, 796: 1420, 797: 1421, 798: 1422, 799: 1423, 800: 1424, 801: 1425,

    # emp47 metadata
    747: 1371, 748: 1372, 749: 1373, 750: 1374,

    # emp63 samples 806-856 + boundary 857
    806: 1426, 807: 1427, 808: 1428, 809: 1429, 810: 1430, 811: 1431, 812: 1432, 813: 1433, 814: 1434, 815: 1435,
    816: 1436, 817: 1437, 818: 1438, 819: 1439, 820: 1440, 821: 1441, 822: 1442, 823: 1443, 824: 1444, 825: 1445,
    826: 1446, 827: 1447, 828: 1448, 829: 1449, 830: 1450, 831: 1451, 832: 1452, 833: 1453, 834: 1454, 835: 1455,
    836: 1456, 837: 1457, 838: 1458, 839: 1459, 840: 1460, 841: 1461, 842: 1462, 843: 1463, 844: 1464, 845: 1465,
    846: 1466, 847: 1467, 848: 1468, 849: 1469, 850: 1470, 851: 1471, 852: 1472, 853: 1473, 854: 1474, 855: 1475, 856: 1476, 857: 1477,

    # emp63 metadata
    802: 1422, 803: 1423, 804: 1424, 805: 1425,

    # emp78 samples 862-911 + boundary 912
    862: 1478, 863: 1479, 864: 1480, 865: 1481, 866: 1482, 867: 1483, 868: 1484, 869: 1485, 870: 1486, 871: 1487,
    872: 1488, 873: 1489, 874: 1490, 875: 1491, 876: 1492, 877: 1493, 878: 1494, 879: 1495, 880: 1496, 881: 1497,
    882: 1498, 883: 1499, 884: 1500, 885: 1501, 886: 1502, 887: 1503, 888: 1504, 889: 1505, 890: 1506, 891: 1507,
    892: 1508, 893: 1509, 894: 1510, 895: 1511, 896: 1512, 897: 1513, 898: 1514, 899: 1515, 900: 1516, 901: 1517,
    902: 1518, 903: 1519, 904: 1520, 905: 1521, 906: 1522, 907: 1523, 908: 1524, 909: 1525, 910: 1526, 911: 1527, 912: 1528,

    # emp78 metadata
    858: 1474, 859: 1475, 860: 1476, 861: 1477,

    # emp85 samples 917-968
    917: 1529, 918: 1530, 919: 1531, 920: 1532, 921: 1533, 922: 1534, 923: 1535, 924: 1536, 925: 1537, 926: 1538,
    927: 1539, 928: 1540, 929: 1541, 930: 1542, 931: 1543, 932: 1544, 933: 1545, 934: 1546, 935: 1547, 936: 1548,
    937: 1549, 938: 1550, 939: 1551, 940: 1552, 941: 1553, 942: 1554, 943: 1555, 944: 1556, 945: 1557, 946: 1558,
    947: 1559, 948: 1560, 949: 1561, 950: 1562, 951: 1563, 952: 1564, 953: 1565, 954: 1566, 955: 1567, 956: 1568,
    957: 1569, 958: 1570, 959: 1571, 960: 1572, 961: 1573, 962: 1574, 963: 1575, 964: 1576, 965: 1577, 966: 1578, 967: 1579, 968: 1580,

    # emp85 metadata
    913: 1525, 914: 1526, 915: 1527, 916: 1528,
}


def renumber_line(line):
    """Renumber f-table references in a line."""
    # Match ftable definitions: "f123" at line start
    line = re.sub(r'^f(\d+)\s', lambda m: f'f{RENUMBER_MAP.get(int(m.group(1)), int(m.group(1)))} ', line)

    # Match ftable references in metadata pairs: space-separated numbers
    # This handles: " 123 " (with spaces) and " 123\n" or " 123$" (at end)
    def replace_num(match):
        num = int(match.group(1))
        if num in RENUMBER_MAP:
            return f' {RENUMBER_MAP[num]}'
        return match.group(0)

    line = re.sub(r'\s(\d+)(?=\s|$)', replace_num, line)

    return line


def process_bosendorfer_tables(ball11_path, output_path):
    """Extract and renumber Bosendorfer f-tables from ball11.csd."""
    print(f"Reading {ball11_path}...")
    with open(ball11_path, 'r') as f:
        lines = f.readlines()

    # Find the Bosendorfer section (starts around line 246 with comment)
    bosendorfer_start = None
    f1_table_line = None

    for i, line in enumerate(lines):
        if 'Orchestra: Bosendorfer' in line:
            bosendorfer_start = i
        if line.startswith('f1 0 64 -2 0 601'):
            f1_table_line = i
            break

    if bosendorfer_start is None or f1_table_line is None:
        print("ERROR: Could not find Bosendorfer section or f1 table")
        return

    # Extract from Bosendorfer comment to f1 table (exclusive)
    bosendorfer_lines = lines[bosendorfer_start:f1_table_line]

    print(f"Extracted {len(bosendorfer_lines)} lines of Bosendorfer definitions")
    print(f"Renumbering f-tables...")

    # Renumber all references
    renumbered_lines = []
    for line in bosendorfer_lines:
        renumbered_line = renumber_line(line)
        renumbered_lines.append(renumbered_line)

    # Convert paths from "./samples/..." to "samples/..."
    renumbered_lines = [line.replace('"./samples/', '"samples/') for line in renumbered_lines]

    # Write output
    with open(output_path, 'w') as f:
        f.writelines(renumbered_lines)

    print(f"Wrote renumbered Bosendorfer definitions to {output_path}")

    # Print summary of f1 address mapping
    print("\nF1 table metadata address mapping:")
    f1_mapping = {601: 1230, 646: 1322, 701: 1326, 747: 1371, 802: 1422, 858: 1474, 913: 1525}
    for old, new in sorted(f1_mapping.items()):
        print(f"  {old} -> {new}")

    print(f"\nNew f1 table values to append: 1230 1322 1326 1371 1422 1474 1525")
    print(f"New f2 table values to append: 5 5 5 5 5 5 5")
    print(f"\nTotal f-tables: {len(RENUMBER_MAP)}")


if __name__ == '__main__':
    process_bosendorfer_tables(
        '/home/prent/Repos/One-footed-bride-tuning/ball11.csd',
        '/home/prent/Repos/One-footed-bride-tuning/bosendorfer_renumbered.txt'
    )
