import csv
import chardet
import datetime
import getpass
import io
import json
from zipfile import ZipFile, ZIP_DEFLATED

remove_zeros_from_json = True
default_strip = [u'', '', None, {}, []]
strip_from_dict = {True: [u'', '', None, {}, [], [0], ['0'], 0, '0'], False: [u'', '', None, {}, []]}
lineterminator = '\n'
min_row_id = 1
fnd_field = 'find_number'
sherd_filed = 'sherd_nr'
source_key_suffix = "-" + str(datetime.datetime.now()).split(".")[0].replace("-", "").replace(" ", "-").replace(":", "") + "-" + getpass.getuser()
default_separators = [',', ';']


def extract_enc(path):
    return chardet.detect(open(path, 'rb').read())['encoding']


def find_separator(path, posible_separators=default_separators, min_num_fields=5):
    counts = {x: {0:0} for x in posible_separators}
    with open(path, 'r', encoding=extract_enc(path)) as data:
        for line in data.readlines():
            for x in counts:
                num_fields = len(line.split(x))
                if min_num_fields < num_fields:
                    if num_fields not in counts[x]:
                        counts[x][num_fields] = 1
                    else:
                        counts[x][num_fields] = 1
    champions = {x: max(counts[x], key=lambda k: counts[x][k]) for x in counts}
    result_1 = max(champions, key=lambda k: champions[k])
    return result_1, champions[result_1]


def convert_data(layer_name, layer_mapping, find_name, find_mapping, site_code, no_header, create_missing, state, separator=None, input_path="./", output_path="./"):
    config = state['config']
    layer_buffer = io.StringIO()
    find_buffer = io.StringIO()
    if separator is None:
        layer_sep, _ = find_separator(layer_name)
        find_sep, _ = find_separator(find_name)
    else:
        layer_sep = separator
        find_sep = separator
    fnd_to_id, layer_writer = convert_layer_data(layer_name, layer_mapping, layer_buffer, config['layer'], site_code, input_path, no_header, layer_sep)
    convert_find_data(find_name, find_mapping, find_buffer, config['find'], site_code, input_path, fnd_to_id, no_header, find_sep, create_missing, layer_writer, state)

    with ZipFile(output_path + site_code + '.zip', 'w', ZIP_DEFLATED) as zip_file:
        zip_file.writestr(site_code + "_layer.csv", layer_buffer.getvalue())
        zip_file.writestr(site_code + "_find.csv", find_buffer.getvalue())


def convert_layer_data(data_file, mapping_file, output_buffer, conversion_dict, site_code, input_path, no_header, separator):
    map_list_layer = []
    output_order = []
    json_lookup = {}
    fnd_to_id = {}

    json_key_word = {'weights': 'weight', 'numbers': ["lt50mm", "gt50mm"], 'counts': 'count'}

    with open(input_path + mapping_file, 'r') as mapping:
        for line in mapping:
            split = line.strip().split('->')
            map_list_layer.append(split[1])

    for pos in conversion_dict['order']:
        col_name = conversion_dict['order'][pos]
        if col_name.startswith("JSON/"):
            name = col_name.strip().lstrip("JSON/")
            output_order.append(name)
            lookup_dict = {}
            json_lookup[name] = lookup_dict
            for lookup_entry in conversion_dict[name]:
                lookup_dict[lookup_entry['property']] = lookup_entry['id']
        else:
            output_order.append(col_name.strip())

    writer = csv.DictWriter(output_buffer, output_order, extrasaction='ignore', restval='NULL', lineterminator=lineterminator)
    writer.writeheader()
    row_id = min_row_id

    with open(input_path + data_file, 'r', encoding=extract_enc(input_path + data_file)) as data:
        layer_reader = csv.reader(data, delimiter=separator)
        if not no_header:
            next(layer_reader, None)
        for r in layer_reader:
            new_record = {'id': row_id, 'find_type': 0, 'source_key': 'TO_BE_CREATED...'}
            source_key = site_code
            fnd_number = None
            row_id += 1
            for jval in json_lookup:
                new_record[jval] = {}
            for c, h in zip(r, map_list_layer):
                if c == "":
                    continue
                if h == fnd_field:
                    if c in fnd_to_id:
                        raise ValueError('Find number is duplicated in layer data')
                    fnd_to_id[c] = new_record['id']
                    fnd_number = c
                if h.split('/')[0] in json_lookup:
                    splited = h.split('/', 1)
                    if splited[1] in json_lookup[splited[0]]:
                        if json_lookup[splited[0]][splited[1]] in new_record[splited[0]]:
                            if splited[0] == 'numbers':
                                if splited[1].split('_')[1] == 'lt':
                                    key_word = json_key_word['numbers'][0]
                                else:
                                    key_word = json_key_word['numbers'][1]
                                new_record[splited[0]][json_lookup[splited[0]][splited[1]]][key_word] = c
                        else:
                            if splited[0] == 'numbers':
                                if splited[1].split('_')[1] == 'lt':
                                    key_word = json_key_word['numbers'][0]
                                else:
                                    key_word = json_key_word['numbers'][1]
                                new_record[splited[0]][json_lookup[splited[0]][splited[1]]] = {key_word: c}
                            else:
                                new_record[splited[0]][json_lookup[splited[0]][splited[1]]] = {json_key_word[splited[0]]: c}

                elif c == "" and h != "#" and h != "???":
                    new_record[h] = None
                elif h != "#" and h != "???":
                    new_record[h] = c

            for jval in json_lookup:
                new_record[jval] = json.dumps(strip_dict(new_record[jval], strip_from_dict[remove_zeros_from_json]), separators=(',', ':'))

            source_key += '-' + str(fnd_number) + '-' + data_file + '-' + str(row_id) + source_key_suffix
            new_record['source_key'] = source_key
            writer.writerow(new_record)

    return fnd_to_id, writer


def convert_find_data(data_file, mapping_file, output_buffer, conversion_dict, site_code, input_path, fnd_to_id, no_header, separator, create_missing, layer_writer, state):
    map_list_find = []
    output_order = []
    json_lookup = {}
    codebook = {}
    codebook_other = {}

    with open(input_path + mapping_file, 'r') as mapping:
        for line in mapping:
            split = line.strip().split('->')
            map_list_find.append(split[1])

    for pos in conversion_dict['order']:
        col_name = conversion_dict['order'][pos]
        if col_name.startswith("JSON/"):
            name = col_name.strip().lstrip("JSON/")
            output_order.append(name)
            lookup_dict = {}
            json_lookup[name] = lookup_dict
            for lookup_entry in conversion_dict[name]:
                lookup_dict[lookup_entry['name']] = lookup_entry['id']
        else:
            output_order.append(col_name.strip())

    for codebook_entry in conversion_dict['codebook']:
        if codebook_entry['attribute_id'] not in codebook:
            codebook[codebook_entry['attribute_id']] = {}
        codebook[codebook_entry['attribute_id']][codebook_entry['code']] = codebook_entry['id']

    for codebook_entry in conversion_dict['codebook_other']:
        if codebook_entry['attribute_id'] not in codebook_other:
            codebook_other[codebook_entry['attribute_id']] = {}
        codebook_other[codebook_entry['attribute_id']][codebook_entry['code']] = codebook_entry['id']

    writer = csv.DictWriter(output_buffer, output_order, extrasaction='ignore', restval='NULL', lineterminator=lineterminator)
    writer.writeheader()

    row_id = min_row_id
    with open(input_path + data_file, 'r', encoding=extract_enc(input_path + data_file)) as csv_data:
        find_reader = csv.reader(csv_data, delimiter=separator)
        if not no_header:
            next(find_reader, None)
        for r in find_reader:
            new_record = {'id': row_id, 'sherd_type': 2, 'source_key': 'TO_BE_CREATED...'}
            source_key = site_code
            fnd_number = None
            sherd_number = None
            for jval in json_lookup:
                new_record[jval] = {}
            for c, h in zip(r, map_list_find):
                if c == "":
                    continue
                if h == fnd_field:
                    if c not in fnd_to_id:
                        if not create_missing:
                            raise ValueError('Find number is missing in layer data: ' + str(c))
                        else:
                            state['logging'].log('Found no layer entry for findnumber ' + str(c) + '. Creating new layer entry.', 1)
                            fnd_to_id[c] = len(fnd_to_id) + 1
                            front_row_number = fnd_to_id[c]
                            front_source_key = site_code + '-' + str(c) + '-' + data_file + '-' + str(front_row_number) + source_key_suffix
                            rem = "Row created during conversion. [SOURCE-KEY: " + front_source_key + "]"
                            layer_writer.writerow({'id': front_row_number, fnd_field: c,  'find_type': 0, 'remarks': rem, 'source_key': front_source_key})
                    new_record['layer_id'] = fnd_to_id[c]
                    fnd_number = c
                elif h == sherd_filed:
                    sherd_number = c
                if h.split('/')[0] in json_lookup:
                    splited = h.split('/', 1)
                    if splited[1] in json_lookup[splited[0]]:
                        if json_lookup[splited[0]][splited[1]] in new_record[splited[0]]:
                            new_record[splited[0]][json_lookup[splited[0]][splited[1]]].append(codebook[json_lookup[splited[0]][splited[1]]][c])
                        else:
                            if c in codebook[json_lookup[splited[0]][splited[1]]]:
                                new_record[splited[0]][json_lookup[splited[0]][splited[1]]] = [codebook[json_lookup[splited[0]][splited[1]]][c]]
                            elif c in codebook_other[json_lookup[splited[0]][splited[1]]]:
                                new_record[splited[0]][json_lookup[splited[0]][splited[1]]] = [codebook_other[json_lookup[splited[0]][splited[1]]][c]]
                                state['logging'].log("[ROW NUMBER " + str(row_id - 1) + "] 'other' value  for " + str(splited[1]) + " code: " + str(c) + "", 1)

                            elif str(c) == '0':
                                # TODO decide if we need to handle this
                                pass
                            else:
                                state['logging'].log("[ROW NUMBER " + str(row_id-1) + "] No entry in codebook for " + str(splited[1]) + " code: " + str(c) + "", 1)

                elif c == "" and h != "#" and h != "???":
                    new_record[h] = None
                elif h != "#" and h != "???":
                    if h in state['convert_to_int']:
                        new_record[h] = int(float(c.replace(',', '.')) * state['convert_to_int'][h])
                    else:
                        new_record[h] = c

            for jval in json_lookup:
                new_record[jval] = json.dumps(strip_dict(new_record[jval], strip_from_dict[remove_zeros_from_json]), separators=(',', ':'))

            if 'layer_id' not in new_record:
                raise ValueError('Could not match up find with layer data. Missing Find number. ' + str(r))

            source_key += '-' + str(fnd_number) + '-' + str(sherd_number) + '-' + data_file + '-' + str(row_id) + source_key_suffix
            new_record['source_key'] = source_key
            writer.writerow(new_record)
            row_id += 1
    return


def strip_dict(data, strip=default_strip):
    new_data = {}
    for k, v in data.items():
        if isinstance(v, dict):
            v = strip_dict(v, strip)
        if v not in strip:
            new_data[k] = v
    return new_data
