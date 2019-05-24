from tkinter import filedialog
from tkinter import ttk
from tkinter import *
import json
import csv

import converter
import cli

default_url = 'http://localhost:8888/get_data_converter_config/api.php?function=getConfig'
find_combo = {'ignore': None, 'find_number': None, 'excavation_code': None, 'sherd_nr': None, 'attribute_values':['Vessel shape', 'Wall profile', 'Lip shape', 'Rim profile', 'Decoration', 'Color outside', 'Color inside', 'Firing color', 'Surface finishing outside', 'Surface finishing inside', 'Slip Position'], 'wall_thickness': None, 'rim_diameter': None, 'rim_percentage': None, 'remarks': None}
layer_combo = {'ignore': None, 'find_number': None, 'excavation_code': None, 'unit': None, 'zone': None, 'sector': None, 'square': None, 'layer': None, 'feature': None, 'weights': ['Body', 'Rim', 'Base', 'Other'], 'numbers': ['Body_lt', 'Rim_lt', 'Base_lt', 'Other_lt', 'Body_gt', 'Rim_gt', 'Base_gt', 'Other_gt'], 'counts': ['Polychrome', 'Broad', 'Anthropomorphic', 'Zoomorphic', 'Geometric', 'Punctation', 'Finger Indentation', 'Nubbin', 'Applique filet', 'Perforation', 'Other', 'Handle', 'Lug', 'Body Stamp', 'Spindle whorl', 'Spout', 'Tool', 'Adorno', 'Flat', 'Convex', 'Concave', 'Concave high', 'Pedestal annular', 'Straight', 'Triangular', 'Overhanging', 'Rounded', 'Legged', 'White slip', 'Red slip'], 'remarks': None}
combo_values = {'find': find_combo, 'layer': layer_combo}
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
        self.state = {'use_defaults': False, 'config_url': default_url, 'convert_to_int': {'wall_thickness': 1, 'rim_diameter': 1, 'rim_percentage': 1}}
        with open('data.json', 'r') as infile:
            self.state['config'] = json.load(infile)
        self.state['logging'] = Logging(2, 2)

        self.currentStep = 0  #TODO start with 0
        self.reset_wizard_step = {0: self.reset_no_reset, 1: self.reset_file_selection, 2: self.reset_file_selection, 3: self.reset_generate_conversion,
                                  4: self.reset_file_selection, 5: self.reset_editor, 6: self.reset_file_selection,
                                  7: self.reset_editor, 8: self.reset_no_reset, 9: self.reset_done}
        self.setup_wizard_step = {0: self.setup_init, 1: self.pick_layer, 2: self.pick_find, 3: self.generate_conversion,
                                  4: self.pick_layer_mapping, 5: self.edit_layer_mapping, 6: self.pick_find_mapping,
                                  7: self.edit_find_mapping, 8: self.show_summary, 9: self.show_done}

        self.fd_title = ""
        self.file_handle = ""
        self.conversionData = {}  #TODO Remove value for mappingfile

        self.myParent = parent
        Grid.rowconfigure(parent, 0, weight=1)
        Grid.columnconfigure(parent, 0, weight=1)

        self.container = Frame(parent)
        self.container.grid(row=0, column=0, sticky=NSEW)

        self.label_guide_string = StringVar()

        self.label_guide = Label(self.container, bg="lightblue", textvariable=self.label_guide_string, justify=LEFT)

        self.label_fp_string = StringVar()

        self.label_fp = Label(self.container, bg="lightblue", textvariable=self.label_fp_string, justify=RIGHT)

        self.button_pick = Button(self.container, text="Pick File")
        self.button_pick.bind("<Button-1>", self.pick_file)

        self.generate_conversion_var = 1
        self.radio_gen = Radiobutton(self.container, text="generate Mapping ", variable=self.generate_conversion_var, value=1)
        self.radio_nogen = Radiobutton(self.container, text="pick Mapping", variable=self.generate_conversion_var, value=2)

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

    def pick_file(self, event):
        report_event(event)
        filename = filedialog.askopenfilename(initialdir=".", title=self.file_handle, filetypes=self.file_types)
        if filename != "":
            self.conversionData[self.file_handle] = filename
            self.label_fp_string.set(filename)
            self.button_next.config(state=NORMAL)

    def next(self, event):
        if self.button_next['state'] == DISABLED:
            return
        self.reset_wizard_step[self.currentStep]()
        self.currentStep += 1
        self.button_back.config(state=NORMAL)
        if self.currentStep + 1 not in self.setup_wizard_step:
            self.button_next.config(state=DISABLED)
        self.setup_wizard_step[self.currentStep]()
        # report_event(event)

    def back(self, event):
        if self.button_back['state'] == DISABLED:
            return
        self.reset_wizard_step[self.currentStep]()
        self.currentStep -= 1
        self.setup_wizard_step[self.currentStep]()
        self.button_next.config(state=NORMAL)
        if self.currentStep - 1 not in self.setup_wizard_step:
            self.button_back.config(state=DISABLED)
        # report_event(event)

    def exit_converter(self, event):
        report_event(event)
        exit(0)
        # self.label_fp_string.set(filename)

    def reset_no_reset(self): pass

    def setup_init(self):
        self.label_guide_string.set("This String explains the use of this converter. It will tell the user all the information necessary to use it.\n   - The front file a.k.a. layer file or bag file\n   - The back file, a.k.a. find file\n   - The mappings for both files. If you don't have one yet this tool will help you with them.")

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

    def setup_pick_file(self, file_types, fp_string, fd_title, file_handle):
        self.file_types = file_types
        self.fd_title = fd_title
        self.file_handle = file_handle
        if self.file_handle in self.conversionData and self.conversionData[self.file_handle]:
            self.label_fp_string.set(self.conversionData[self.file_handle])
        else:
            self.label_fp_string.set(fp_string)
            self.button_next.config(state=DISABLED)
        self.label_fp.grid(row=2, column=0, columnspan=3, rowspan=2, sticky=E+W, padx='5', pady='15')
        self.button_pick.grid(row=2, column=3, sticky=W, padx='5', pady='15')

    def generate_conversion(self):
        self.radio_gen.grid(column=1, columnspan=1, row=2)
        self.radio_nogen.grid(column=2, columnspan=1, row=2)

        self.label_guide_string.set("Do you want to create two new conversion mapping files for the data you provided?\n "
                                    "The file should be in the txt format.")

    def reset_generate_conversion(self):
        if self.generate_conversion_var < 2:
            self.conversionData["findmapping"] = "./find_mapping.txt"
            self.conversionData["layermapping"] = "./layer_mapping.txt"
            sep, _ = converter.find_separator(self.conversionData["layer"])
            with open(self.conversionData["layer"], "r", encoding=converter.extract_enc(self.conversionData["layer"])) as f:
                header = csv.DictReader(f, delimiter=sep).fieldnames
            with open('layer_mapping.txt', "w") as f:
                for col in header:
                    if col in cli.known_fields["layer"]:
                        f.write(col + "->" + cli.known_fields['layer'][col] + "\n")
                    else:
                        f.write(col + "->#\n")

            sep, _ = converter.find_separator(self.conversionData["find"])
            with open(self.conversionData["find"], "r", encoding=converter.extract_enc(self.conversionData["find"])) as f:
                header = csv.DictReader(f, delimiter=sep).fieldnames
            with open('find_mapping.txt', "w") as f:
                for col in header:
                    if col in cli.known_fields["find"]:
                        f.write(col + "->" + cli.known_fields['find'][col] + "\n")
                    else:
                        f.write(col + "->#\n")
        self.radio_gen.grid_forget()
        self.radio_nogen.grid_forget()

    def pick_layer_mapping(self):
        self.label_guide_string.set("Please pick the mapping file for the layer file \n "
                                    "The file should be in the txt format.")
        self.setup_pick_file((("txt files", "*.txt"), ("all files", "*.*")), "Please pick the mapping layer file",
                             "layer mapping file", "layermapping")

    def reset_file_selection(self):
        self.label_fp.grid_forget()
        self.button_pick.grid_forget()

    def reset_editor(self):
        self.save_mapping()
        self.editor_canvas.grid_forget()
        self.scroll_y.grid_forget()
        self.label_guide.grid(row=0, column=0, columnspan=4, rowspan=2, sticky=W+E+N+S, padx='15', pady='15')

    def pick_find_mapping(self):
        self.file_types = (("txt files", "*.txt"), ("all files", "*.*"))
        self.label_guide_string.set("Please pick the the mapping file for the find file.\n "
                                    "The file should be in the txt format.")
        self.setup_pick_file((("txt files", "*.txt"), ("all files", "*.*")), "Please pick the find mapping file",
                             "find mapping file", "findmapping")

    def edit_layer_mapping(self):
        self.setup_mapping_editor(self.conversionData["layermapping"], 'layer')

    def edit_find_mapping(self):
        self.setup_mapping_editor(self.conversionData["findmapping"], 'find')

    def combo_selection(self, event):
        row_number = str(event.widget).split('=')[-1]
        # print_to_stdout(str(event.widget)) #
        # print_to_stdout(event.widget.get())

        self.setup_second_combo(self.editor_elements[int(row_number)][2], combo_values[self.editor_mode][event.widget.get()], "")
        if event.widget.get() in combo_values[self.editor_mode] and combo_values[self.editor_mode][event.widget.get()]:
            self.editor_elements[int(row_number)][2].config(state="normal")
        else:
            self.editor_elements[int(row_number)][2].config(state="disabled")

    def setup_second_combo(self, combobox, values, value):
        combobox.config(values=values)
        combobox.set(value)

    def save_mapping(self):
        self.conversionData[self.editor_mode + "mapping"] += '.new'
        with open(self.conversionData[self.editor_mode + "mapping"], 'w') as new_mapping:
            for row in self.editor_elements:
                if combo_values[self.editor_mode][row[1].get()]:
                    new_mapping.write(row[0].cget("text") + '->' + row[1].get() + '/' + row[2].get() + '\n')
                else:
                    new_mapping.write(row[0].cget("text") + '->' + row[1].get() + '\n')

    def setup_mapping_editor(self, mapping_file_name, editor_mode):
        self.label_guide.grid_forget()
        self.editor_mode = editor_mode
        mapping = []
        with open(mapping_file_name, 'r') as mapping_file:
            for line in mapping_file.readlines():
                line_parts1 = line.strip().split('->')
                line_parts2 = line_parts1[1].split('/')
                if len(line_parts2) > 1:
                    mapping.append([line_parts1[0], line_parts2[0], line_parts2[1]])
                else:
                    mapping.append([line_parts1[0], line_parts1[1]])
        self.editor_elements = []
        if self.editor_canvas:
            self.editor_frame.destroy()
        self.editor_canvas = Canvas(self.container)
        self.scroll_y = Scrollbar(self.container, orient="vertical", command=self.editor_canvas.yview)
        self.editor_frame = Frame(self.editor_canvas)
        self.editor_frame.configure(background='lightblue')
        for mapping_item, idx in zip(mapping, range(len(mapping))):
            if mapping_item[1] == '#': mapping_item[1] = 'ignore'
            lbl = Label(self.editor_frame, text=mapping_item[0], justify=LEFT)
            lbl.grid(column=0, row=idx, sticky=E, padx=5)

            combo = ttk.Combobox(self.editor_frame, values=list(combo_values[editor_mode].keys()), name="combobox1_row=" + str(idx))
            combo.bind("<<ComboboxSelected>>", self.combo_selection)
            combo.set(mapping_item[1])
            combo.grid(column=1, row=idx)

            combo2 = ttk.Combobox(self.editor_frame, width=40)
            if combo_values[editor_mode][mapping_item[1]]:
                self.setup_second_combo(combo2, combo_values[editor_mode][mapping_item[1]], mapping_item[2])
            else:
                combo2.config(state="disabled")
            combo2.grid(column=2, row=idx)

            self.editor_elements.append((lbl, combo, combo2))

        self.editor_canvas.create_window(0, 0, anchor='nw', window=self.editor_frame)
        self.editor_canvas.bind('<Configure>', lambda event: print_to_stdout(event))

        self.editor_frame.bind("<Configure>", lambda _: self.editor_canvas.configure(scrollregion=self.editor_canvas.bbox("all"), yscrollcommand=self.scroll_y.set))

        self.editor_canvas.grid(row=0, column=0, columnspan=4, rowspan=2, padx='5', pady='15', sticky=N+S+E+W)
        self.scroll_y.grid(row=0, column=3, rowspan=2, sticky=N+S+E, padx='5', pady='15')

    def show_summary(self):
        self.button_pick.grid_forget()
        self.label_fp.grid_forget()

        self.label_guide_string.set('Summary:\n' + str(self.conversionData).replace(',', '\n'))

    def reset_done(self):
        self.button_save.grid_forget()
        self.button_next.config(state=NORMAL)

    def show_done(self):
        filename = filedialog.asksaveasfilename(initialdir=".", title=self.file_handle, filetypes=(("zip files", "*.zip"), ("all files", "*.*")))
        if filename == "":
            self.back(None)
            return
        converter.convert_data(self.conversionData['layer'], self.conversionData['layermapping'], self.conversionData['find'], self.conversionData['findmapping'], "site_code", False, True, self.state, None, "", "", filename)

        self.label_guide_string.set("The conversion was successful. To save the result click the button blow.")

        self.button_next.config(state=DISABLED)
        self.button_save.grid(row=2, column=0, columnspan=4, rowspan=1, sticky=W+E+N+S, padx='15', pady='15')


def print_to_stdout(str):
    print(str)


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