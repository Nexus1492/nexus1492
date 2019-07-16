#!/usr/bin/env python3
import click
import csv
import json
import os.path
import requests
import sys

import converter

default_url = 'http://localhost:8888/get_data_converter_config/api.php?function=getConfig'
state = {'use_defaults': False, 'config_url': default_url, 'convert_to_int': {'wall_thickness': 1, 'rim_diameter': 1, 'rim_percentage': 1}}
known_layer = {"FND": "find_number", "site": "excavation_code", "unit": "unit", "zone": "zone", "sector": "sector", "square": "square", "layer": "layer", "feature": "feature", "body weight": "weights/Body", "body <50mm": "numbers/Body_lt", "body >50mm": "numbers/Body_gt", "rim weight": "weights/Rim", "rim <50mm": "numbers/Rim_lt", "rim >50mm": "numbers/Rim_gt", "base weight": "weights/Base", "base <50mm": "numbers/Base_lt", "base >50mm": "numbers/Base_gt", "griddle/other weight": "weights/Other", "griddle/other <50mm": "numbers/Other_lt", "griddle/other >50mm": "numbers/Other_gt", "polychrome painting": "counts/Polychrome", "broad-line incision": "counts/Broad", "mod anthrop": "counts/Anthropomorphic", "mod zoomop": "counts/Zoomorphic", "mod geom": "counts/Geometric", "punctation": "counts/Punctation", "finger indentation": "counts/Finger Indentation", "nubbin": "counts/Nubbin", "appliqué filet": "counts/Applique filet", "perforation": "counts/Perforation", "other": "counts/Other", "handle": "counts/Handle", "lug": "counts/Lug", "bodystamp": "counts/Body Stamp", "spindle whorl": "counts/Spindle whorl", "spout": "counts/Spout", "tool": "counts/Tool", "adorno": "counts/Adorno", "flat": "counts/Flat", "convex": "counts/Convex", "concave": "counts/Concave", "concave high": "counts/Concave high", "pedestal/annular": "counts/Pedestal annular", "straight": "counts/Straight", "triangular": "counts/Triangular", "overhanging": "counts/Overhanging", "rounded": "counts/Rounded", "legged": "counts/Legged", "white slip": "counts/White slip", "red slip": "counts/Red slip", "remarks": "remarks"}
known_find = {"FND": "find_number", "site": "excavation_code", "nr": "sherd_nr", "vsh": "attribute_values/Vessel shape", "wp": "attribute_values/Wall profile", "lsh": "attribute_values/Lip shape", "rpr": "attribute_values/Rim profile", "wth": "wall_thickness", "dm": "rim_diameter", "%": "rim_percentage", "dec": "attribute_values/Decoration", "clo": "attribute_values/Color outside", "cli": "attribute_values/Color inside", "fat": "attribute_values/Firing color", "sfo": "attribute_values/Surface finishing outside", "sfi": "attribute_values/Surface finishing inside", "slp": "attribute_values/Slip Position", "mnf": "#", "hrd": "#", "rem": "remarks"}
known_fields = {'layer': known_layer, 'find': known_find}


class OptionPrompt(click.Option):
    def prompt_for_value(self, ctx):
        if not state['use_defaults']:
            return super(OptionPrompt, self).prompt_for_value(ctx)
        return self.get_default(ctx)


class Logging:
    def __init__(self, log_level_std_out=2, log_level_file=0, log_file='converter.log'):
        self.log_level_std_out = log_level_std_out
        self.log_level_file = log_level_file
        self.log_file_name = log_file

    def log(self, msg, level=1):
        if level <= self.log_level_std_out:
            click.echo(msg)
        if level <= self.log_level_file:
            with open(self.log_file_name, 'a') as out_file:
                out_file.write(msg + '\n')


def set_use_defaults(ctx, _, value):
    if not value or ctx.resilient_parsing:
        return
    state['use_defaults'] = True


def update_local(ctx, _, value):
    if not value or ctx.resilient_parsing:
        return
    try:
        download_config()
        state['logging'].log("Update complete.", 2)
        exit(0)
    except requests.exceptions.RequestException:
        state['logging'].log("Not able to load configuration from server. Aborting.", 2)
        exit(1)


def load_config():
    if not state['use_local']:
        try:
            state['config'] = download_config()
        except requests.exceptions.RequestException:
            state['logging'].log("Not able to load configuration from server. Using latest local configuration.", 2)
            open_config()
    else:
        open_config()


def open_config():
    try:
        with open('data.json', 'r') as infile:
            state['config'] = json.load(infile)
    except FileNotFoundError:
        state['logging'].log("Not able to load configuration from file. Aborting.", 2)
        exit(1)


def download_config():
    r = requests.get(state['config_url'])
    config = r.json()['data']
    with open('data.json', 'w') as outfile:
        json.dump(config, outfile, indent=4)
    return config


@click.option('--URL', default=default_url, help='URL of the web frontend to load the configuration from.')
@click.option('--use_local', is_flag=True, help='Use the local configuration')
@click.option('--logging_file', default=2, help='logging level for logging to file')
@click.option('--logging_stdout', default=2, help='logging level for logging to standard out')
@click.option('--update_local', is_flag=True, help='Update the local configuration and exit.', callback=update_local)
@click.group()
def cli(url, use_local, logging_file, logging_stdout, update_local):
    state['logging'] = Logging(logging_stdout, logging_file)
    state['use_local'] = use_local
    state['config_url'] = url


@click.command("create_mapping")
@click.option('--layer', cls=OptionPrompt, default='layer.csv', prompt='path to the layer csv file', help='layer data (a.k.a front table or bags) to convert')
@click.option('--find', cls=OptionPrompt, default='find.csv', prompt='path to the find csv file', help=' find data (a.k.a back table or rim sherds) to convert')
@click.option('--raise_errors', is_flag=True, help='Show full error messages')
@click.option('--separator', default=None, help='sets the separator for the CSV files')
def create_mapping(layer, find, raise_errors, separator):
    """Creates mapping templates."""
    # TODO use converter for this
    try:
        with open(layer, "r", encoding=converter.extract_enc(layer)) as f:
            header = csv.DictReader(f).fieldnames
        with open('layer_mapping.txt', "w") as f:
            for col in header:
                if col in known_fields["layer"]:
                    f.write(col + "->" + known_fields['layer'][col] + "\n")
                else:
                    f.write(col + "->#\n")

        with open(find, "r", encoding=converter.extract_enc(find)) as f:
            header = csv.DictReader(f).fieldnames
        with open('find_mapping.txt', "w") as f:
            for col in header:
                if col in known_fields["find"]:
                    f.write(col + "->" + known_fields['find'][col] + "\n")
                else:
                    f.write(col + "->#\n")
        state['logging'].log('writing layermapping and findmapping...\nDone.', 2)
    except Exception as e:
        state['logging'].log("Something went wrong during the conversion. A " + str(sys.exc_info()[0].__name__) + " occurred:\n" + str(e), 2)
        if raise_errors:
            raise


@click.command("convert")
@click.option('--layer', cls=OptionPrompt, default='layer.csv', prompt='path to the layer csv file', help='layer data (a.k.a front table or bags) to convert')
@click.option('--find', cls=OptionPrompt, default='find.csv', prompt='path to the find csv file', help=' find data (a.k.a back table or rim sherds) to convert')
@click.option('--layermapping', cls=OptionPrompt, default='layer_mapping.txt', prompt='path to the layer mapping file', help='mapping of the layer columns in the input file to the ones in the database')
@click.option('--findmapping', cls=OptionPrompt, default='find_mapping.txt', prompt='path to the find find file', help='mapping of the layer columns in the input file to the ones in the database')
@click.option('--site', prompt='Site code', help='Code of the site to use during the conversion')
@click.option('--use_defaults', is_flag=True, is_eager=True, help='Use the defaults for all arguments', callback=set_use_defaults)
@click.option('--no_header', is_flag=True, is_eager=True, help='Specify if layer and find file have no headers')
@click.option('--create_missing', is_flag=True, help='Create missing layer entries for finds.')
@click.option('--raise_errors', is_flag=True, help='Show full error messages')
@click.option('--separator', default=None, help='sets the separator for the CSV files')
@click.option('--overwrite_output', is_flag=True, help='Overwrite output file if it already exists')
def convert(layer, find, layermapping, findmapping, site, use_defaults, no_header, create_missing, raise_errors, separator, overwrite_output):
    """Converts data. Simple program converting layer data (a.k.a front table or bags) and find data (a.k.a back table or rim sherds)
        for usage with the unified database with the web frontend. Only use this if you know what you are doing."""
    try:
        load_config()
        if not site.isalnum():
            state['logging'].log('Site needs to only contain a letters and digits.', 2)
            exit(0)
        elif os.path.isfile(str(site) + '.zip') and not overwrite_output:
            state['logging'].log('Output file already exists. Use \'--overwrite_output\' to overwrite the existing file.', 2)
            exit(0)
        converter.convert_data_old(layer, layermapping, find, findmapping, site, no_header, create_missing, state, separator)
        state['logging'].log('Done.', 2)
    except Exception as e:
        state['logging'].log("Something went wrong during the conversion. A " + str(sys.exc_info()[0].__name__) + " occurred:\n" + str(e), 2)
        if raise_errors:
            raise

@click.command("check_sep")
@click.option('--file', cls=OptionPrompt, default='layer.csv', prompt='path to the csv file', help='file to check')
def check_sep(file):
    """Checks a csv file for the separator used and prints it along with the number of columns."""
    sep, cols = converter.find_separator(file)
    state['logging'].log(str(file) + ":  Separator: '" + str(sep) + "', Number of fields:  " + str(cols), 2)


if __name__ == '__main__':
    cli.add_command(convert)
    cli.add_command(create_mapping)
    cli.add_command(check_sep)
    cli()