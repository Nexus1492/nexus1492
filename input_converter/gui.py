from tkinter import filedialog, messagebox
from tkinter import ttk
from tkinter import *
from sys import exit
import json
import os.path
import re

import converter
import cli

default_url = 'http://localhost:8888/get_data_converter_config/api.php?function=getConfig'
find_cols = ['ignore', 'find_number', 'excavation_code', 'sherd_nr', 'attribute_values', 'wall_thickness', 'rim_diameter', 'rim_percentage', 'remarks']
layer_cols = ['ignore', 'find_number', 'excavation_code', 'unit', 'zone', 'sector', 'square', 'layer', 'feature', 'weights', 'numbers', 'counts', 'remarks']

class Logging:
    def __init__(self, log_level_std_out=2, log_level_file=0, log_file='converter_gui.log'):
        self.log_level_std_out = log_level_std_out
        self.log_level_file = log_level_file
        self.log_file_name = log_file

    def log(self, msg, level=1):
        if level <= self.log_level_std_out:
            print(msg)
        if level <= self.log_level_file:
            with open(self.log_file_name, 'a') as out_file:
                out_file.write(msg + '\n')


class MyApp:
    def __init__(self, parent):
        self.myParent = parent
        self.state = {'use_defaults': False, 'config_url': default_url, 'convert_to_int': {'wall_thickness': 1, 'rim_diameter': 1, 'rim_percentage': 1}}
        with open('data.json', 'r') as infile:
            self.state['config'] = json.load(infile)
        self.state['logging'] = Logging(2, 2)

        self.layer_combo = {}
        self.find_combo = {}
        self.combo_values = {'find': self.find_combo, 'layer': self.layer_combo}
        for col in layer_cols:
            if col in self.state['config']['layer']:
                self.layer_combo[col] = [x['property'] for x in self.state['config']['layer'][col]]
            else:
                self.layer_combo[col] = None
        for col in find_cols:
            if col in self.state['config']['find']:
                self.find_combo[col] = [x['name'] for x in self.state['config']['find'][col]]
            else:
                self.find_combo[col] = None

        self.currentStep = 0  #TODO start with 0
        self.reset_wizard_step = {0: self.reset_start_msg, 1: self.reset_file_selection, 2: self.reset_file_selection, 3: self.reset_generate_conversion,
                                  4: self.reset_file_selection, 5: self.reset_editor, 6: self.reset_file_selection,
                                  7: self.reset_editor, 8: self.reset_no_reset, 9: self.reset_done}
        self.setup_wizard_step = {0: self.setup_init, 1: self.pick_layer, 2: self.pick_find, 3: self.generate_conversion,
                                  4: self.pick_layer_mapping, 5: self.edit_layer_mapping, 6: self.pick_find_mapping,
                                  7: self.edit_find_mapping, 8: self.show_summary, 9: self.convert_and_show_done}

        self.fd_title = ""
        self.file_handle = ""

        answer_redo = messagebox.askyesno("Data Converter", "Do you want to redo a previous conversion?")
        if answer_redo:
            self.redo_conversion = True
            self.save_file = filedialog.askopenfilename(initialdir=".", title="Pick savefile", filetypes=[("converter savefile", "*.foo")])
            with open(self.save_file, "r") as save_file:
                self.conversionData = json.load(save_file)

        else:
            self.redo_conversion = False
            self.save_file  = filedialog.asksaveasfilename(initialdir=".", title="Enter name for savefile",
                                                    filetypes=[("converter savefile", "*.foo")],
                                                    defaultextension='foo',
                                                    initialfile="state_save")

            self.conversionData = {'site_code': ''}

        Grid.rowconfigure(parent, 0, weight=1)
        Grid.columnconfigure(parent, 0, weight=1)

        self.container = Frame(parent)
        self.container.grid(row=0, column=0, sticky=NSEW)

        self.label_guide_string = StringVar()

        self.label_guide = Label(self.container, bg="lightblue", textvariable=self.label_guide_string, justify=LEFT)

        self.text_box_site_code = Entry(self.container, width=10, bg="orange")

        self.label_fp_string = StringVar()

        self.label_fp = Label(self.container, bg="lightblue", textvariable=self.label_fp_string, justify=RIGHT)

        self.button_pick = Button(self.container, text="Pick File")
        self.button_pick.bind("<Button-1>", self.pick_file)

        self.generate_conversion_var = StringVar()
        self.generate_conversion_var.set("gen")
        self.radio_gen = Radiobutton(self.container, text="generate Mapping ", variable=self.generate_conversion_var, value="gen")
        self.radio_nogen = Radiobutton(self.container, text="pick Mapping", variable=self.generate_conversion_var, value="no_gen")

        self.button_save = Button(self.container, text="Close the Converter")
        self.button_save.bind("<Button-1>", self.exit_converter)

        self.button_next = Button(self.container, text="Next >")
        self.button_next.grid(row=2, column=3, sticky=SE, padx='15', pady='15')
        self.button_next.bind("<Button-1>", self.next)

        self.button_back = Button(self.container, text="< Back")
        self.button_back.grid(row=2, column=2, sticky=SW, padx='15', pady='15')
        self.button_back.bind("<Button-1>", self.back)
        self.button_back.config(state=DISABLED)

        self.editor_canvas = None

        self.scroll_y = None  #
        self.editor_frame = None
        self.editor_elements = []
        self.editor_mode = None

        Grid.columnconfigure(self.container, 0, weight=1)
        Grid.columnconfigure(self.container, 1, weight=1)
        Grid.columnconfigure(self.container, 2, weight=1)
        Grid.rowconfigure(self.container, 0, weight=1)
        Grid.rowconfigure(self.container, 1, weight=1)
        Grid.rowconfigure(self.container, 2, weight=1)
        self.label_guide.grid(row=0, column=0, columnspan=4, rowspan=2, sticky=W+E+N+S, padx='15', pady='15')
        self.setup_wizard_step[self.currentStep]()

    # next and back
    def next(self, _):
        if self.button_next['state'] == DISABLED:
            return
        self.reset_wizard_step[self.currentStep]()
        self.currentStep += 1
        self.button_back.config(state=NORMAL)
        if self.currentStep + 1 not in self.setup_wizard_step:
            self.button_next.config(state=DISABLED)
        if self.setup_wizard_step[self.currentStep]() == 'skip':
            self.next(None)
        self.save_conversion_data()

    def back(self, _):
        if self.button_back['state'] == DISABLED:
            return
        self.reset_wizard_step[self.currentStep]()
        self.currentStep -= 1
        self.button_next.config(state=NORMAL)
        if self.currentStep - 1 not in self.setup_wizard_step:
            self.button_back.config(state=DISABLED)
        if self.setup_wizard_step[self.currentStep]() == 'skip':
            self.back(None)
        self.save_conversion_data()

    # setup , happens before showing step
    def setup_init(self):
        self.text_box_site_code.delete(0, END)
        self.text_box_site_code.insert(0,self.conversionData['site_code'])
        self.text_box_site_code.grid(row=2, column=0, columnspan=3, rowspan=1, sticky=N)
        self.text_box_site_code.focus_set()
        self.label_guide_string.set("This wizard will help you to convert databases containing data collected for sherds.\n"
                                    "It will guide you through all the steps necessary. To to do the conversion you will need:\n"
                                    "   - The front file a.k.a. layer file or bag file\n"
                                    "   - The back file, a.k.a. find file\n"
                                    "Those files must be in the *.csv format and must contain the column names in the first line.\n"
                                    "You also need two mappings from the columns of the csv-file to the new data format.If you don't\n"
                                    "have one yet this tool will help you with them.\n To start please enter the code of the site you wish to convert:")

    def pick_layer(self):
        self.file_types = (("csv files", "*.csv"), ("all files", "*.*"))
        self.label_guide_string.set("Please pick the front file a.k.a. layer file or bag file\n "
                                    "The file should be in the csv format.")
        self.setup_pick_file((("csv files", "*.csv"), ("all files", "*.*")), "Please pick the layer file",
                             "layer file", "layer")

    def pick_find(self):
        self.file_types = (("csv files", "*.csv"), ("all files", "*.*"))
        self.label_guide_string.set("Please pick the the back file, a.k.a. find file.\n "
                                    "The file should be in the csv format.")
        self.setup_pick_file((("csv files", "*.csv"), ("all files", "*.*")), "Please pick the find file",
                             "find file", "find")

    def generate_conversion(self):
        if self.redo_conversion:
            return 'skip'
        self.radio_gen.grid(column=1, columnspan=1, row=2)
        self.radio_nogen.grid(column=2, columnspan=1, row=2)

        self.label_guide_string.set("Do you want to create two new conversion mapping files for the data you provided?\n "
                                    "The file should be in the txt format.")

    def pick_layer_mapping(self):
        if self.generate_conversion_var.get() == "gen":
            return 'skip'
        self.label_guide_string.set("Please pick the mapping file for the layer file \n "
                                    "The file should be in the txt format.")
        self.setup_pick_file((("txt files", "*.txt"), ("all files", "*.*")), "Please pick the mapping layer file",
                             "layer mapping file", "layermapping_path")

    def edit_layer_mapping(self):
        if self.generate_conversion_var.get() != "gen":
            _, self.conversionData["layermapping"] = converter.read_mapping(self.conversionData["layermapping_path"])
        self.setup_mapping_editor(self.conversionData["layermapping"], 'layer')

    def pick_find_mapping(self):
        if self.generate_conversion_var.get() == "gen":
            return 'skip'
        self.file_types = (("txt files", "*.txt"), ("all files", "*.*"))
        self.label_guide_string.set("Please pick the the mapping file for the find file.\n "
                                    "The file should be in the txt format.")
        self.setup_pick_file((("txt files", "*.txt"), ("all files", "*.*")), "Please pick the find mapping file",
                             "find mapping file", "findmapping_path")

    def edit_find_mapping(self):
        if self.generate_conversion_var.get() != "gen":
            _, self.conversionData["findmapping"] = converter.read_mapping(self.conversionData["findmapping_path"])
        self.setup_mapping_editor(self.conversionData["findmapping"], 'find')

    def show_summary(self):
        self.button_pick.grid_forget()
        self.label_fp.grid_forget()
        summary_str = "Summary:\n"
        summary_str += "Site code: " + self.conversionData['site_code'] + "\n"
        summary_str += "Layer csv: " + self.conversionData['layer'] + "\n"
        summary_str += "Find csv: " + self.conversionData['find']
        self.label_guide_string.set(summary_str)

    def convert_and_show_done(self):
        filename = filedialog.asksaveasfilename(initialdir=".", title=self.file_handle, filetypes=(("zip files", "*.zip"), ("all files", "*.*")), defaultextension='zip', initialfile=self.conversionData['site_code'])

        if filename == "":
            self.back(None)
            return

        self.state['layer_mapping'] = converter.transform_mapping(self.conversionData["layermapping"])
        self.state['find_mapping'] = converter.transform_mapping(self.conversionData["findmapping"])
        self.state['layer_name'] = self.conversionData['layer']
        self.state['find_name'] = self.conversionData['find']
        self.state['site_code'] = self.conversionData['site_code']
        self.state['no_header'] = False
        self.state['create_missing'] = True
        self.state['output_file_name'] = filename
        self.state['layer_sep'], _ = converter.find_separator(self.conversionData['layer'])
        self.state['find_sep'], _ = converter.find_separator(self.conversionData['find'])

        try:
            warnings = converter.convert(self.state)
        except:
            warnings = {'success': False}
        if warnings['success']:
            lbl_str = "The conversion was successful.\nNumber of warnings during the conversion:\n"
            lbl_str += "   - " + str(warnings['missing_front']) + " layer entries were missing\n"
            lbl_str += "   - " + str(warnings['other_codes']) + " \"OTHER\" codes were found\n"
            lbl_str += "   - " + str(warnings['missing_codebook_entry']) + " codes were not in the codebook"
        else:
            lbl_str = "Somethings went wrong. Please check the log file for more details."

        self.label_guide_string.set(lbl_str)
        self.button_next.config(state=DISABLED)
        self.button_save.grid(row=2, column=0, columnspan=4, rowspan=1, sticky=W+E+N+S, padx='50', pady='50')

    # reset, happens when leaving step
    def reset_no_reset(self): pass

    def reset_start_msg(self):
        self.text_box_site_code.grid_forget()
        site_code = re.sub(r'\W+', '', self.text_box_site_code.get())
        self.conversionData['site_code'] = site_code if len(site_code) > 0 else "NONE"

    def reset_file_selection(self):
        self.label_fp.grid_forget()
        self.button_pick.grid_forget()

    def reset_generate_conversion(self):
        if self.generate_conversion_var.get() == "gen":
            self.conversionData["findmapping_path"] = "./find_mapping.txt"
            self.conversionData["layermapping_path"] = "./layer_mapping.txt"
            # TODO remove cli known fields
            self.conversionData["layermapping"] = converter.generate_mapping(self.conversionData["layer"], cli.known_fields["layer"])
            # MyApp.write_mapping_to_file(self.conversionData["layermapping"],  self.conversionData["layermapping_path"])

            self.conversionData["findmapping"] = converter.generate_mapping(self.conversionData["find"], cli.known_fields["find"])
            # MyApp.write_mapping_to_file(self.conversionData["findmapping"],  self.conversionData["findmapping_path"])

        self.radio_gen.grid_forget()
        self.radio_nogen.grid_forget()

    def reset_editor(self):
        self.conversionData[self.editor_mode + "mapping"] = self.get_mapping_from_editor()
        self.editor_canvas.grid_forget()
        self.scroll_y.grid_forget()
        self.label_guide.grid(row=0, column=0, columnspan=4, rowspan=2, sticky=W+E+N+S, padx='15', pady='15')

    def reset_done(self):
        self.button_save.grid_forget()
        self.button_next.config(state=NORMAL)

    # common helpers
    def save_conversion_data(self):
        with open(self.save_file, 'w') as save_file:
            json.dump(self.conversionData, save_file)

    def pick_file(self, event):
        filename = filedialog.askopenfilename(initialdir=".", title=self.file_handle, filetypes=self.file_types)

        if filename != "":
            self.conversionData[self.file_handle] = filename
            self.label_fp_string.set(filename)
            self.label_fp.config(fg='black')
            self.button_next.config(state=NORMAL)

    def setup_pick_file(self, file_types, fp_string, fd_title, file_handle):
        self.file_types = file_types
        self.fd_title = fd_title
        self.file_handle = file_handle
        if self.file_handle in self.conversionData and self.conversionData[self.file_handle]:
            if not os.path.isfile(self.conversionData[self.file_handle]):
                self.button_next.config(state=DISABLED)
                self.label_fp.config(fg='red')
                self.label_fp_string.set(self.conversionData[self.file_handle] + "   " + u'\u2718')
            else:
                self.label_fp.config(fg='darkgreen')
                self.label_fp_string.set(self.conversionData[self.file_handle] + "   " + u'\u2714')
        else:
            self.label_fp_string.set(fp_string)
            self.button_next.config(state=DISABLED)
        self.label_fp.grid(row=2, column=0, columnspan=3, rowspan=2, sticky=E+W, padx='5', pady='15')
        self.button_pick.grid(row=2, column=3, sticky=W, padx='5', pady='15')

    @staticmethod
    def write_mapping_to_file(mapping, path):
        with open(path , "w") as f:
            for col in mapping:
                mapped = mapping[col] if mapping[col] is not None else '#'
                f.write(col + "->" + str(mapped) + "\n")

    def exit_converter(self, event):
        exit(0)

    # mapping editor
    def setup_mapping_editor(self, mapping, editor_mode):
        self.label_guide.grid_forget()
        self.editor_mode = editor_mode

        self.editor_elements = []
        if self.editor_canvas:
            self.editor_frame.destroy()
        self.editor_canvas = Canvas(self.container)
        self.scroll_y = Scrollbar(self.container, orient="vertical", command=self.editor_canvas.yview)
        self.editor_frame = Frame(self.editor_canvas)
        self.editor_frame.configure(background='lightblue')
        for mapping_key, idx in zip(mapping, range(len(mapping))):
            mapping_item = [mapping_key] + mapping[mapping_key].split('/')

            if mapping_item[1] == '#': mapping_item[1] = 'ignore'
            lbl = Label(self.editor_frame, text=mapping_item[0], justify=LEFT)
            lbl.grid(column=0, row=idx, sticky=E, padx=5)

            combo = ttk.Combobox(self.editor_frame, values=list(self.combo_values[editor_mode].keys()), name="combobox1_row=" + str(idx))
            combo.bind("<<ComboboxSelected>>", self.combo_selection)
            combo.set(mapping_item[1])
            combo.grid(column=1, row=idx)

            combo2 = ttk.Combobox(self.editor_frame, width=40)
            if self.combo_values[editor_mode][mapping_item[1]]:
                self.setup_second_combo(combo2, self.combo_values[editor_mode][mapping_item[1]], mapping_item[2])
            else:
                combo2.config(state="disabled")
            combo2.grid(column=2, row=idx)

            self.editor_elements.append((lbl, combo, combo2))

        self.editor_canvas.create_window(0, 0, anchor='nw', window=self.editor_frame)
        self.editor_canvas.bind('<Configure>', lambda event: print(event))

        self.editor_frame.bind("<Configure>", lambda _: self.editor_canvas.configure(scrollregion=self.editor_canvas.bbox("all"), yscrollcommand=self.scroll_y.set))

        self.editor_canvas.grid(row=0, column=0, columnspan=4, rowspan=2, padx='5', pady='15', sticky=N+S+E+W)
        self.scroll_y.grid(row=0, column=3, rowspan=2, sticky=N+S+E, padx='5', pady='15')

    def get_mapping_from_editor(self):
        new_mapping = {}
        for row in self.editor_elements:
            if self.combo_values[self.editor_mode][row[1].get()]:
                new_mapping[row[0].cget("text")] = row[1].get() + '/' + row[2].get()
            else:
                new_mapping[row[0].cget("text")] = '#' if row[1].get() == 'ignore' else row[1].get()
        return new_mapping

    def setup_second_combo(self, combobox, values, value):
        combobox.config(values=values)
        combobox.set(value)

    def combo_selection(self, event):
        row_number = str(event.widget).split('=')[-1]

        self.setup_second_combo(self.editor_elements[int(row_number)][2], self.combo_values[self.editor_mode][event.widget.get()], "")
        if event.widget.get() in self.combo_values[self.editor_mode] and self.combo_values[self.editor_mode][event.widget.get()]:
            self.editor_elements[int(row_number)][2].config(state="normal")
        else:
            self.editor_elements[int(row_number)][2].config(state="disabled")


def report_event(event):  ### (5)
    """Print a description of an event, based on its attributes.
    """
    print("Time:", str(event.time))
    print("EventType=" + str(event.type), "EventKeySymbol=" + str(event.keysym))


root = Tk()
root.title("Data Converter")
w = 800 # width for the Tk root
h = 400 # height for the Tk root

# get screen width and height
ws = root.winfo_screenwidth() # width of the screen
hs = root.winfo_screenheight() # height of the screen

# calculate x and y coordinates for the Tk root window
x = (ws/2) - (w/2)
y = (hs/2) - (h/2)

# set the dimensions of the screen
# and where it is placed
root.geometry('%dx%d+%d+%d' % (w, h, x, y))

my_app = MyApp(root)
root.mainloop()