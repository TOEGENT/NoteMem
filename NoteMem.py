
from datetime import time as tt
from kivymd.uix.pickers import MDTimePicker
from kivymd.uix.pickers import MDTimePicker
import functools
import pickle
import kivy
from kivymd.uix.dialog import MDDialog
from kivy.lang import Builder
from kivymd.app import MDApp
import time
from plyer import audio
from kivy.core.window import Window
from kivymd.uix.filemanager import MDFileManager
from kivymd.uix.button import *
from kivymd.uix.fitimage import FitImage
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.theming import ThemeManager
from kivymd.uix.textfield import MDTextField
from kivymd.uix.menu import MDDropdownMenu
from kivymd.uix.button import MDIconButton
from kivy.uix.slider import Slider
from kivy.app import App
from kivy.uix.button import Button
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.popup import Popup
from kivy.animation import Animation
from kivy.uix.textinput import TextInput
from kivymd.uix.scrollview import MDScrollView
from kivy.uix.scrollview import ScrollView
from kivy.uix.modalview import ModalView
from kivymd.uix.relativelayout import MDRelativeLayout
from kivy.uix.relativelayout import RelativeLayout
from kivymd.uix.floatlayout import FloatLayout, MDFloatLayout
from kivy.uix.gridlayout import GridLayout
from kivymd.uix.gridlayout import MDGridLayout
from kivy.uix.image import Image

from kivymd.uix.label.label import MDIcon
from kivymd.uix.screenmanager import MDScreenManager
from kivymd.uix.screen import MDScreen
from kivymd.uix.behaviors import TouchBehavior
import platform
# from android.permissions import request_permissions, Permission
# request_permissions([Permission.CAMERA,Permission.READ_EXTERNAL_STORAGE, Permission.WRITE_EXTERNAL_STORAGE,Permission.RECORD_AUDIO])
from datetime import datetime
from kivy.clock import Clock

from kivy.core.window import Window
from kivy.uix.carousel import Carousel
from kivy.uix.filechooser import FileChooserIconView
from kivy.lang import Builder
from kivy.uix.camera import Camera
from kivy.uix.behaviors import ButtonBehavior
from kivymd.uix.label import MDLabel
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.app import MDApp
from kivymd.uix.list import MDList
from kivymd.uix.list import OneLineAvatarIconListItem
from kivy.uix.scatter import Scatter
from kivymd.uix.behaviors import (
    CircularRippleBehavior,
    CommonElevationBehavior,
)

screens = "main"  # текущее окно интерфейса
matrix_file = "DATA4.pickle"  # файл хранения матрицы данных

try:  # пытаемся открыть файл с фоточками
    pickle.load(open("PATH.pickle", 'rb'))
except:  # иначе создаём собственный
    path = "/sdcard/DCIM/photos"
    pickle.dump(path, open("PATH.pickle", 'wb'))
format_ = "jpg"  # формат фото
try:  # пытаемся открыть файл с темами программы
    theme = pickle.load(open("theme.pickle", 'rb'))
    print(theme)
except:  # иначе сами делаем тему
    theme = "Dark"
    pickle.dump(theme, open("theme.pickle", 'wb'))


def MinusData(data1, data2):  # функция для вычислений с датами
    return (data1[0] * 360 + data1[1] * 30 + data1[2] * 1) - (data2[0] * 360 + data2[1] * 30 + data2[2] * 1)


def datachange(datatime, days):  # для изменения даты на n дней

    datatime[2] += int(days)

    while datatime[2] > 30:
        datatime[2] = datatime[2] - 30
        datatime[1] += 1
    while datatime[1] > 12:
        datatime[1] = datatime[1] - 12
        datatime[0] += 1
    while datatime[2] <= 0:
        datatime[2] = 31 + datatime[2]
        datatime[1] -= 1
    while datatime[1] <= 0:
        datatime[1] = 12
        datatime[0] -= 1
    return datatime


def data_recover(blocks, deadline):  # генератор матрицы дат
    result = []
    now = [datetime.now().year, datetime.now().month, datetime.now().day, datetime.now().hour, datetime.now().minute]
    block_per_day = round(blocks / deadline[-1])
    result.append(datachange(now.copy(), -1) + [deadline[0] * 480])
    result.append(datachange(now.copy(), -2) + [deadline[1] * 1440])
    result.append(datachange(now.copy(), -3) + [deadline[1] * 1440])
    for i2 in range(1, deadline[-1] + 1):
        for i in range(1, block_per_day + 1):
            result.append(datachange(now.copy(), -(i2)) + [deadline[-1] * 1440])
    return result[:-3]


kok = 0.1  # дистанция анимации выдвижения кнопок настройки
learn_symbol = "@^&#"
KVV = '''
<Content>
    orientation: "vertical"
    spacing: "6dp"
    size_hint_y: None
    height: "40dp"

    MDSlider:
        step:1
        max:5
        min:1



MDFloatLayout:

    MDFlatButton:
        text: "ALERT DIALOG"
        pos_hint: {'center_x': .5, 'center_y': .5}
        on_release: app.show_confirmation_dialog()
'''
KVV2 = '''
<Content_limit>
    orientation: "vertical"
    spacing: "6dp"
    size_hint_y: None
    height: "40dp"

    MDSlider:
        step:1
        max:20
        min:1



MDFloatLayout:

    MDFlatButton:
        text: "ALERT DIALOG"
        pos_hint: {'center_x': .5, 'center_y': .5}
        on_release: app.show_confirmation_dialog()
'''


class Content(BoxLayout):
    pass


class Content_limit(BoxLayout):
    pass


filters_list = {1: "все",
                2: "учить"}
id = 0  # если 0 то новый блок
color_dict = {
    'Red': {'50': 'FFEBEE', '100': 'FFCDD2', '200': 'EF9A9A', '300': 'E57373', '400': 'EF5350', '500': 'F44336',
            '600': 'E53935', '700': 'D32F2F', '800': 'C62828', '900': 'B71C1C', 'A100': 'FF8A80', 'A200': 'FF5252',
            'A400': 'FF1744', 'A700': 'D50000'},
    'Pink': {'50': 'FCE4EC', '100': 'F8BBD0', '200': 'F48FB1', '300': 'F06292', '400': 'EC407A', '500': 'E91E63',
             '600': 'D81B60', '700': 'C2185B', '800': 'AD1457', '900': '880E4F', 'A100': 'FF80AB', 'A200': 'FF4081',
             'A400': 'F50057', 'A700': 'C51162'},
    'Purple': {'50': 'F3E5F5', '100': 'E1BEE7', '200': 'CE93D8', '300': 'BA68C8', '400': 'AB47BC', '500': '9C27B0',
               '600': '8E24AA', '700': '7B1FA2', '800': '6A1B9A', '900': '4A148C', 'A100': 'EA80FC', 'A200': 'E040FB',
               'A400': 'D500F9', 'A700': 'AA00FF'},
    'DeepPurple': {'50': 'EDE7F6', '100': 'D1C4E9', '200': 'B39DDB', '300': '9575CD', '400': '7E57C2', '500': '673AB7',
                   '600': '5E35B1', '700': '512DA8', '800': '4527A0', '900': '311B92', 'A100': 'B388FF',
                   'A200': '7C4DFF', 'A400': '651FFF', 'A700': '6200EA'},
    'Indigo': {'50': 'E8EAF6', '100': 'C5CAE9', '200': '9FA8DA', '300': '7986CB', '400': '5C6BC0', '500': '3F51B5',
               '600': '3949AB', '700': '303F9F', '800': '283593', '900': '1A237E', 'A100': '8C9EFF', 'A200': '536DFE',
               'A400': '3D5AFE', 'A700': '304FFE'},
    'Blue': {'50': 'E3F2FD', '100': 'BBDEFB', '200': '90CAF9', '300': '64B5F6', '400': '42A5F5', '500': '2196F3',
             '600': '1E88E5', '700': '1976D2', '800': '1565C0', '900': '0D47A1', 'A100': '82B1FF', 'A200': '448AFF',
             'A400': '2979FF', 'A700': '2962FF'},
    'LightBlue': {'50': 'E1F5FE', '100': 'B3E5FC', '200': '81D4FA', '300': '4FC3F7', '400': '29B6F6', '500': '03A9F4',
                  '600': '039BE5', '700': '0288D1', '800': '0277BD', '900': '01579B', 'A100': '80D8FF',
                  'A200': '40C4FF', 'A400': '00B0FF', 'A700': '0091EA'},
    'Cyan': {'50': 'E0F7FA', '100': 'B2EBF2', '200': '80DEEA', '300': '4DD0E1', '400': '26C6DA', '500': '00BCD4',
             '600': '00ACC1', '700': '0097A7', '800': '00838F', '900': '006064', 'A100': '84FFFF', 'A200': '18FFFF',
             'A400': '00E5FF', 'A700': '00B8D4'},
    'Teal': {'50': 'E0F2F1', '100': 'B2DFDB', '200': '80CBC4', '300': '4DB6AC', '400': '26A69A', '500': '009688',
             '600': '00897B', '700': '00796B', '800': '00695C', '900': '004D40', 'A100': 'A7FFEB', 'A200': '64FFDA',
             'A400': '1DE9B6', 'A700': '00BFA5'},
    'Green': {'50': 'E8F5E9', '100': 'C8E6C9', '200': 'A5D6A7', '300': '81C784', '400': '66BB6A', '500': '4CAF50',
              '600': '43A047', '700': '388E3C', '800': '2E7D32', '900': '1B5E20', 'A100': 'B9F6CA', 'A200': '69F0AE',
              'A400': '00E676', 'A700': '00C853'},
    'LightGreen': {'50': 'F1F8E9', '100': 'DCEDC8', '200': 'C5E1A5', '300': 'AED581', '400': '9CCC65', '500': '8BC34A',
                   '600': '7CB342', '700': '689F38', '800': '558B2F', '900': '33691E', 'A100': 'CCFF90',
                   'A200': 'B2FF59', 'A400': '76FF03', 'A700': '64DD17'},
    'Lime': {'50': 'F9FBE7', '100': 'F0F4C3', '200': 'E6EE9C', '300': 'DCE775', '400': 'D4E157', '500': 'CDDC39',
             '600': 'C0CA33', '700': 'AFB42B', '800': '9E9D24', '900': '827717', 'A100': 'F4FF81', 'A200': 'EEFF41',
             'A400': 'C6FF00', 'A700': 'AEEA00'},
    'Yellow': {'50': 'FFFDE7', '100': 'FFF9C4', '200': 'FFF59D', '300': 'FFF176', '400': 'FFEE58', '500': 'FFEB3B',
               '600': 'FDD835', '700': 'FBC02D', '800': 'F9A825', '900': 'F57F17', 'A100': 'FFFF8D', 'A200': 'FFFF00',
               'A400': 'FFEA00', 'A700': 'FFD600'},
    'Amber': {'50': 'FFF8E1', '100': 'FFECB3', '200': 'FFE082', '300': 'FFD54F', '400': 'FFCA28', '500': 'FFC107',
              '600': 'FFB300', '700': 'FFA000', '800': 'FF8F00', '900': 'FF6F00', 'A100': 'FFE57F', 'A200': 'FFD740',
              'A400': 'FFC400', 'A700': 'FFAB00'},
    'Orange': {'50': 'FFF3E0', '100': 'FFE0B2', '200': 'FFCC80', '300': 'FFB74D', '400': 'FFA726', '500': 'FF9800',
               '600': 'FB8C00', '700': 'F57C00', '800': 'EF6C00', '900': 'E65100', 'A100': 'FFD180', 'A200': 'FFAB40',
               'A400': 'FF9100', 'A700': 'FF6D00'},
    'DeepOrange': {'50': 'FBE9E7', '100': 'FFCCBC', '200': 'FFAB91', '300': 'FF8A65', '400': 'FF7043', '500': 'FF5722',
                   '600': 'F4511E', '700': 'E64A19', '800': 'D84315', '900': 'BF360C', 'A100': 'FF9E80',
                   'A200': 'FF6E40', 'A400': 'FF3D00', 'A700': 'DD2C00'},
    'Brown': {'50': 'EFEBE9', '100': 'D7CCC8', '200': 'BCAAA4', '300': 'A1887F', '400': '8D6E63', '500': '795548',
              '600': '6D4C41', '700': '5D4037', '800': '4E342E', '900': '3E2723', 'A100': '000000', 'A200': '000000',
              'A400': '000000', 'A700': '000000'},
    'Gray': {'50': 'FAFAFA', '100': 'F5F5F5', '200': 'EEEEEE', '300': 'E0E0E0', '400': 'BDBDBD', '500': '9E9E9E',
             '600': '757575', '700': '616161', '800': '424242', '900': '212121', 'A100': '000000', 'A200': '000000',
             'A400': '000000', 'A700': '000000'},
    'BlueGray': {'50': 'ECEFF1', '100': 'CFD8DC', '200': 'B0BEC5', '300': '90A4AE', '400': '78909C', '500': '607D8B',
                 '600': '546E7A', '700': '455A64', '800': '37474F', '900': '263238', 'A100': '000000', 'A200': '000000',
                 'A400': '000000', 'A700': '000000'},
    'Light': {'StatusBar': 'E0E0E0', 'AppBar': 'F5F5F5', 'Background': 'FAFAFA', 'CardsDialogs': 'FFFFFF',
              'FlatButtonDown': 'cccccc'},
    'Dark': {'StatusBar': '000000', 'AppBar': '1f1f1f', 'Background': '121212', 'CardsDialogs': '212121',
             'FlatButtonDown': '999999'}}
try:
    color = pickle.load(open("color.pickle", 'rb'))
except:
    color = "Red"
    pickle.dump(color, open("color.pickle", "wb"))
main_animation = "in_out_cubic"
main_color = None
current_item = ""
line_size = .6
button_size = 10
"""filters_list = {
    1: "по дате",
    2: "все",
    3: "учить"
}"""
image_list = {}
try:
    limit = pickle.load(open("LIMIT.pickle", 'rb'))
except:
    limit = 6
    pickle.dump(limit, open("LIMIT.pickle", 'wb'))


class CustomButton(MDFillRoundFlatButton):  # скелет для кнопок
    def __init__(self, **kwargs):
        super().__init__(
            line_width=4 * line_size,
            size_hint=(.01 * button_size, 0.01 * button_size),
            md_bg_color=color_dict[color]["900"],
            line_color=(0, 0, 0, 1),
            _radius=100,
            **kwargs

        )


class CameraClick(MDScreen):  # камера
    def __init__(self, **kwargs):
        super(CameraClick, self).__init__(**kwargs)
        self.scat = Scatter(
            rotation=-90,
            do_rotation=False,
            do_scale=False,
            do_translation=True)
        self.camera = Builder.load_string(
            """
Camera:
    id: camera
    resolution: (1920, 1080)
    size_hint:(2,1)
    pos_hint:{'center_x':.5}
    play: True
    canvas.before:
        PushMatrix
        Rotate:
            angle: -90
            origin: self.center
    canvas.after:
        PopMatrix""")
        self.capture_button = CustomButton(on_press=self.capture)
        self.exit_btn = CustomButton(
            theme_icon_color="Custom",
            icon_color="#311021",
            on_press=self.on_exit,
            pos_hint={"center_x": .9, "center_y": 0.915},
        )
        self.exit_btn.add_widget(MDIcon(icon="exit-to-app", ))
        self.add_widget(self.scat)
        self.add_widget(self.camera)
        self.add_widget(self.capture_button)
        self.add_widget(self.exit_btn)

    def on_pre_enter(self, *args):

        print(self.manager.screens)

        if color != pickle.load(open("color.pickle", "rb")):
            for i in self.children:
                if "MDScrollView" not in str(i):
                    setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def on_exit(self, b):
        self.manager.transition.direction = 'left'
        self.manager.current = "editor"

    def capture(self, b):
        path = pickle.load(open("PATH.pickle", 'rb'))
        timestr = time.strftime("%d-%m-%Y_%H-%M-%S")
        self.camera.export_to_png(f"{path}/IMG_{timestr}.{format_}")
        matrix = pickle.load(open(matrix_file, 'rb'))
        matrix[self.manager.get_screen("editor").idd]["image"].append(f"{path}/IMG_{timestr}.{format_}")
        image_list[self.manager.get_screen("editor").idd][f"{path}/IMG_{timestr}.{format_}"] = None
        pickle.dump(matrix, open(matrix_file, 'wb'))


class SettingsPrompt(MDScreen):
    def __init__(self, **kwargs):
        super(SettingsPrompt, self).__init__(**kwargs)
        self.scrollvieww = MDScrollView(size_hint=(1, 0.9))
        self.overall_layout = MDBoxLayout(orientation="vertical", adaptive_height=True, spacing=20)  # Не скроллится
        self.gui_layout = MDBoxLayout(
            md_bg_color=color_dict[color]["900"],
            pos_hint={"center_x": .5, "center_y": .95},
            size_hint=(1, 0.1))
        print(color)
        self.exit_btn = CustomButton(
            theme_icon_color="Custom",
            icon_color=color_dict[color]["900"],
            pos_hint={"center_x": .9, "center_y": 0.915},
        )
        self.exit_btn.add_widget(MDIcon(icon="exit-to-app", ))
        self.list_layout = MDList()
        self.overall_layout.add_widget(self.list_layout)
        self.scrollvieww.add_widget(self.overall_layout)

        KV = """
MDLabel
    text: "настройки"
    font_size:50
    valgin: "center"
    halign: "center"
        """
        self.settings_text = Builder.load_string(KV)

        self.add_widget(self.gui_layout)
        self.add_widget(self.scrollvieww)
        self.add_widget(self.exit_btn)
        self.gui_layout.add_widget(self.settings_text)


class Text_Screen(SettingsPrompt):
    def __init__(self, **kwargs):
        super(Text_Screen, self).__init__(**kwargs)
        self.settings_text.text = "Блокнот"
        self.remove_widget(self.exit_btn)
        self.text_input = TextInput(size_hint=(1, 0.9))
        self.remove_widget(self.scrollvieww)
        self.add_widget(self.text_input)
        self.add_widget(self.exit_btn)
        self.matrix = pickle.load(open(matrix_file, 'rb'))
        self.exit_btn.on_press = self.on_exit

    def on_exit(self):
        self.manager.transition.direction = 'left'
        print(screens)
        self.manager.current = "editor"

    def on_pre_enter(self, *args):
        print("Text_Screen 1", self.manager.screens)
        print("Text_Screen 2", self.manager.screens)
        self.matrix = pickle.load(open(matrix_file, 'rb'))
        self.text_input.text = self.matrix[self.manager.get_screen("editor").idd]["text"]

        if color != pickle.load(open("color.pickle", "rb")):
            for i in self.children:
                if "MDScrollView" not in str(i):
                    setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def on_pre_leave(self, *args):

        self.matrix[self.manager.get_screen("editor").idd]["text"] = self.text_input.text  # @@@@@@@@
        pickle.dump(self.matrix, open(matrix_file, 'wb'))


class Mp3Screen(SettingsPrompt):
    def __init__(self, **kwargs):
        super(Mp3Screen, self).__init__(**kwargs)
        self.s = 0
        self.s2 = 0
        self.Audio = audio
        self.settings_text.text = "Аудиофайлы"
        self.add_mp3_button = CustomButton(
            pos_hint={"center_x": .8, "center_y": .915},
            on_press=self.add_audio)
        self.add_widget(self.add_mp3_button)
        self.add_mp3_button.add_widget(MDIcon(icon="plus"))

        self.record_button_start = CustomButton(
            pos_hint=self.exit_btn.pos_hint,
            on_press=self.record)
        self.record_button_start.add_widget(MDIcon(icon="microphone"))
        self.animation_close = Animation(
            opacity=0,
            duration=.5)
        self.animation_start = Animation(
            opacity=1,
            duration=0.5)
        self.exit_btn.on_press = self.on_exit

    def on_exit(self):
        self.manager.transition.direction = 'left'
        print(screens)
        self.manager.current = "editor"

    def on_pre_enter(self, *args):
        screens = "editor"
        if color != pickle.load(open("color.pickle", "rb")):
            for i in self.children:
                if "MDScrollView" not in str(i):
                    setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def add_audio(self, b):
        if not self.s:
            self.add_mp3_button.children[0].icon = "close"
            self.add_widget(self.record_button_start)

    def close_audio(self, b):
        self.add_mp3_button.children[0].icon = "plus"
        self.remove_widget(self.record_button_start)

    def record(self, b):
        if not self.s2:
            self.record_button_start.children[0].icon = "check"
            self.Audio.start()
            self.s2 = 1
        else:

            self.record_button_start.children[0].icon = "microphone"
            self.Audio.stop()
            self.s2 = 0


class FilterSettings(SettingsPrompt):
    def __init__(self, **kwargs):
        super(FilterSettings, self).__init__(**kwargs)
        self.storage = "filters.pickle"
        self.current_name = "filter"
        try:
            self.filters_list = pickle.load(open(self.storage, 'rb'))
        except:
            pickle.dump(["все", 'учить'], open(self.storage, 'wb'))
            self.filters_list = pickle.load(open(self.storage, 'rb'))
        self.s = 0

        self.add_layout = MDFloatLayout()
        self.text_input = MDTextField(
            pos_hint={"center_y": 0.4},
            pos=(90, 0),
            size_hint=[0.2, 0.2],
        )
        self.apply_add_filter_button = MDIconButton(
            icon="check",
            pos_hint={"right": .8, "center_y": .5},
            on_press=self.confirm_text
        )
        self.list_add_item = MDIconButton(icon="plus", pos_hint={"right": .94, "center_y": .9})
        self.filters = OneLineAvatarIconListItem(
            text="фильтры")
        self.settings_text.text = "фильтры"
        self.scrollvieww.clear_widgets()
        self.list_layout.clear_widgets()
        self.add_layout.add_widget(self.list_add_item)
        self.scrollvieww.add_widget(self.overall_layout)
        self.overall_layout.add_widget(self.add_layout)
        self.on_load_widgets()
        self.exit_btn.on_press = self.on_exit

    def on_exit(self):
        self.manager.transition.direction = 'left'
        print(screens)
        self.manager.current = "settings"

    def on_load_widgets(self):
        for i in list(self.filters_list.keys()):
            self.list_item = OneLineAvatarIconListItem(
                text=str(self.filters_list[i]))
            KV = """
IconRightWidget:
    icon: 'minus'"""
            minus_icon = Builder.load_string(KV)
            minus_icon.on_press = lambda id=i, item=self.list_item: self.delete_button(id, item)
            self.list_item.add_widget(minus_icon)
            self.list_layout.add_widget(self.list_item)

        self.list_add_item.on_press = lambda id=len(self.filters_list) + 1, item=self.list_item: self.add_button(id,
                                                                                                                 item)
        self.shelter = OneLineAvatarIconListItem(pos_hint={"center_y": 1})

    def on_pre_enter(self, *args):
        print("filters 1", self.manager.screens)
        screens = "editor"
        if self.filters_list == {}:
            self.filters_list = {0: "все", 1: "учить"}

        for i in self.children:
            if "MDScrollView" not in str(i):
                setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def confirm_text(self, b):
        id_ = max(list(self.filters_list.keys())) + 1
        self.filters_list[id_] = self.text_input.text
        keys_ = list(self.filters_list.keys())
        sorted_values = list(self.filters_list.values())
        sorted_values.sort()

        for i in range(len(sorted_values)):
            self.filters_list[keys_[i]] = sorted_values[i]
        self.text_input.text = ""
        pickle.dump(self.filters_list, open(self.storage, 'wb'))
        self.list_layout.clear_widgets()
        self.on_load_widgets()

    def add_button(self, matrix_item, button):
        if not self.s:
            self.add_layout.add_widget(self.shelter)
            self.list_add_item.icon = "close"
            self.s += 1
            self.add_layout.add_widget(self.text_input)
            self.add_layout.add_widget(self.apply_add_filter_button)


        else:
            self.list_add_item.icon = "plus"
            self.s = 0
            self.add_layout.clear_widgets()
            self.add_layout.add_widget(self.list_add_item)

    def delete_button(self, matrix_item, button):
        self.list_layout.remove_widget(button)
        del self.filters_list[matrix_item]
        pickle.dump(self.filters_list, open(self.storage, "wb"))


class IntervalsScreen(SettingsPrompt):
    def __init__(self, **kwargs):
        super(IntervalsScreen, self).__init__(**kwargs)
        self.storage = "intervals.pickle"
        self.current_name = "intervals"
        self.settings_text.text = "интервалы"
        try:
            self.filters_list = pickle.load(open(self.storage, 'rb'))
        except:
            pickle.dump({0: 480, 1: 2880, 2: 8640}, open(self.storage, 'wb'))
            self.filters_list = pickle.load(open(self.storage, 'rb'))
        self.s = 0

        self.add_layout = MDFloatLayout()
        self.text_input = MDTextField(
            pos_hint={"center_y": 0.4},
            pos=(90, 0),
            size_hint=[0.2, 0.2],
        )
        self.apply_add_filter_button = MDIconButton(
            icon="check",
            pos_hint={"right": .8, "center_y": .5},
            on_press=self.confirm_text
        )
        self.list_add_item = MDIconButton(icon="plus", pos_hint={"right": .94, "center_y": .9})
        self.filters = OneLineAvatarIconListItem(
            text="фильтры")

        self.scrollvieww.clear_widgets()
        self.list_layout.clear_widgets()
        self.add_layout.add_widget(self.list_add_item)
        self.scrollvieww.add_widget(self.overall_layout)
        # self.mdlist = MDList(md_bg_color=color_dict["Red"]["500"])
        self.overall_layout.add_widget(self.add_layout)
        self.on_load_widgets()
        self.exit_btn.on_press = self.on_exit

    def on_exit(self):
        self.manager.transition.direction = 'left'
        self.manager.current = "settings"

    def on_load_widgets(self):
        for i in list(self.filters_list.keys()):
            self.list_item = OneLineAvatarIconListItem(
                text=str(self.filters_list[i]))
            KV = """
IconRightWidget:
    icon: 'minus'"""
            minus_icon = Builder.load_string(KV)
            minus_icon.on_press = lambda id=i, item=self.list_item: self.delete_button(id, item)
            self.list_item.add_widget(minus_icon)
            self.list_layout.add_widget(self.list_item)
            # self.overall_layout.add_widget(self.mdlist)

            self.list_add_item.on_press = lambda id=len(self.filters_list) + 1, item=self.list_item: self.add_button(id,
                                                                                                                     item)
        self.shelter = OneLineAvatarIconListItem(pos_hint={"center_y": 1})

        for i in self.children:
            if "MDScrollView" not in str(i):
                setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def on_pre_enter(self, *args):
        screens = "settings"
        if self.filters_list == {}:
            self.filters_list = {0: 480, 1: 2880, 2: 8640}
        print("IntervalSettings 1", self.manager.screens)

        for i in self.children:
            if "MDScrollView" not in str(i):
                setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
        print("IntervaSettings 2", self.manager.screens)

        self.time_values = [1, 10, 60, 300, 1440, 7200, 36000]
        self.menu = MDDropdownMenu(
            caller=self.list_add_item,
            items=[
                {
                    "text": f"{i}",
                    "viewclass": "OneLineListItem",
                    "on_release": lambda x=f"Item {i}",
                                         k=i: self.confirm_text(k),
                } for i in self.time_values
            ],
            width_mult=4,
        )

    def confirm_text(self, item):
        if len(list(self.filters_list.keys())) == 0:
            id_ = 0
        else:
            id_ = max(list(self.filters_list.keys())) + 1
        self.filters_list[id_] = item
        keys_ = list(self.filters_list.keys())
        sorted_values = list(self.filters_list.values())
        sorted_values.sort()

        for i in range(len(sorted_values)):
            self.filters_list[keys_[i]] = sorted_values[i]
        self.text_input.text = ""
        pickle.dump(self.filters_list, open(self.storage, 'wb'))
        self.list_layout.clear_widgets()
        self.on_load_widgets()

    def add_button(self, matrix_item, button):
        self.menu.open()

    def delete_button(self, matrix_item, button):
        self.list_layout.remove_widget(button)
        del self.filters_list[matrix_item]
        pickle.dump(self.filters_list, open(self.storage, "wb"))


class SettingsScreen(SettingsPrompt):
    def __init__(self, **kwargs):
        super(SettingsScreen, self).__init__(**kwargs)

        Builder.load_string(KVV)  # диалог
        Builder.load_string(KVV2)  # диадог
        self.s = 0
        self.filters_list = None
        self.time_picker = MDTimePicker()
        self.intervals_list = None
        self.filters = OneLineAvatarIconListItem(
            on_press=self.filters_window,
            text="фильтры")
        self.intervals = OneLineAvatarIconListItem(
            on_press=self.intervals_window,
            text="промежутки")

        self.color_changer = OneLineAvatarIconListItem(
            text="цвет"
        )
        self.dialog = MDDialog(
            title="на сколько дней?",
            type="custom",
            content_cls=Content(),
            buttons=[
                MDFlatButton(
                    text="НАЗАД",
                    theme_text_color="Custom",
                    on_release=lambda x: self.dialog.dismiss(),

                ),
                MDFlatButton(
                    text="OK",
                    theme_text_color="Custom",
                    on_release=self.print_slider_value,

                ),
            ],
        )
        self.dialog_limit = MDDialog(
            title="лимит",
            type="custom",
            content_cls=Content_limit(),
            buttons=[
                MDFlatButton(
                    text="НАЗАД",
                    theme_text_color="Custom",
                    on_release=lambda x: self.dialog_limit.dismiss(),

                ),
                MDFlatButton(
                    text="OK",
                    theme_text_color="Custom",
                    on_release=self.confirm_limit,

                ),
            ],
        )
        self.dialog_time = MDDialog(
            title="на какое время?",
            type="custom",
            content_cls=Content(),
            buttons=[
                MDFlatButton(
                    text="НАЗАД",
                    theme_text_color="Custom",
                    on_release=lambda x: self.dialog_time.dismiss(),

                ),
                MDFlatButton(
                    text="OK",
                    theme_text_color="Custom",
                    on_release=self.change_time,

                ),
            ],
        )
        # colors
        self.freeze = OneLineAvatarIconListItem(
            on_press=self.freeze_dates,
            text="заморозить"
        )
        self.change_time_button = OneLineAvatarIconListItem(
            on_press=self.on_change_time,
            text="изменить время"
        )
        self.reset = OneLineAvatarIconListItem(
            on_press=self.reset_dates,
            text="сбросить даты"
        )
        self.limit_button = OneLineAvatarIconListItem(
            on_press=self.on_change_limit,
            text="строки на страницу"
        )
        self.file_chooser = MDFileManager(
            exit_manager=self.exit_manager,
            select_path=self.path_changer, )
        self.path = OneLineAvatarIconListItem(
            on_press=self.open_manager,
            text="изменить путь")
        self.dir = OneLineAvatarIconListItem()
        textt = MDTextField(
            size_hint=(.6, None),
            hint_text="искать...",
            pos_hint={"center_x": 0.5, "center_y": 0.5},
            line_color_focus="white",
            on_text_validate=self.change_dir,
            text_color_focus="white", )

        self.dir.add_widget(textt)
        # colors
        red = MDIconButton(
            theme_icon_color="Custom",
            icon="circle",
            pos_hint={"center_x": .8, "center_y": .5},
            icon_color=color_dict["Red"]["400"],
            size=[.001, .3],
            on_press=lambda x: self.change_color("Red"))
        green = MDIconButton(
            theme_icon_color="Custom",
            icon="circle",
            pos_hint={"center_x": .7, "center_y": .5},
            icon_color=color_dict["Green"]["400"],
            size=[.001, .3],
            on_press=lambda x: self.change_color("Green"))
        purple = MDIconButton(
            theme_icon_color="Custom",
            icon="circle",
            pos_hint={"center_x": .6, "center_y": .5},
            icon_color=color_dict["Purple"]["400"],
            size=[.001, .3],
            on_press=lambda x: self.change_color("Purple"))
        blue = MDIconButton(
            theme_icon_color="Custom",
            icon="circle",
            pos_hint={"center_x": .5, "center_y": .5},
            icon_color=color_dict["Blue"]["400"],
            size=[.001, .3],
            on_press=lambda x: self.change_color("Blue"))
        theme_button = MDIconButton(
            icon="theme-light-dark",
            pos_hint={"center_x": .5, "center_y": .1},
            size=[.001, .3],
            on_release=MyApp.switch_theme_style)

        self.color_changer.add_widget(red)
        self.color_changer.add_widget(green)
        self.color_changer.add_widget(purple)
        self.color_changer.add_widget(blue)
        self.list_layout.add_widget(self.filters)
        self.list_layout.add_widget(self.intervals)
        self.list_layout.add_widget(self.path)
        self.list_layout.add_widget(self.color_changer)
        self.list_layout.add_widget(self.freeze)
        self.list_layout.add_widget(self.change_time_button)
        self.list_layout.add_widget(self.reset)
        self.list_layout.add_widget(self.limit_button)
        self.list_layout.add_widget(self.dir)
        self.add_widget(theme_button)
        self.exit_btn.on_press = self.on_exit

    def reset_dates(self, *args):
        matrix = pickle.load(open(matrix_file, 'rb'))
        data = data_recover(len(matrix), [1, 2, 6])

        for i, k in zip(matrix, range(1, len(data))):
            matrix[i]["date"] = data[-k][:-1]
            matrix[i]["time"] = data[-k][-1]
            matrix[i]["learn"] = False

        pickle.dump(matrix, open(matrix_file, 'wb'))

    def on_change_time(self, *args):

        self.time_picker.bind(on_save=self.change_time, on_chanel=lambda x: self.time_picker.dismiss())
        self.time_picker.open()

    def change_time(self, *args):
        pickle.dump(self.time_picker.time, open("TIMEE.pickle", 'wb'))
        matrix = pickle.load(open(matrix_file, 'rb'))
        for i in matrix:
            matrix[i]["date"][3] = self.time_picker.time.hour
            matrix[i]["date"][4] = self.time_picker.time.minute
        pickle.dump(matrix, open(matrix_file, "wb"))
        self.dialog_time.dismiss()

    def confirm_limit(self, *args):
        pickle.dump(self.dialog_limit.content_cls.children[0].value, open("LIMIT.pickle", 'wb'))
        limit = pickle.load(open("LIMIT.pickle", 'rb'))
        self.dialog_limit.dismiss()

    def on_change_limit(self, b):
        self.dialog_limit.open()

    def change_dir(self, b):

        pickle.dump(b.text, open("PATH.pickle", "wb"))

    def open_manager(self, b):
        self.file_chooser.show(pickle.load(open("PATH.pickle", 'rb')))

    def exit_manager(self, b):
        self.file_chooser.close()

    def path_changer(self, path, b=False):
        pickle.dump(path, open("PATH.pickle", 'wb'))

    def on_exit(self):
        self.manager.transition.direction = 'left'
        self.manager.current = "main"

    def freeze_dates(self, a):

        self.dialog.open()

    def print_slider_value(self, *args):  # определите эту функцию
        pickle.dump(-self.dialog.content_cls.children[0].value * 1440, open("time.pickle", 'wb'))
        self.dialog.dismiss()

    def change_color(self, colorr):
        pickle.dump(colorr, open("color.pickle", 'wb'))
        setattr(self.gui_layout, 'md_bg_color', color_dict[colorr]["900"])
        setattr(self.exit_btn, 'md_bg_color', color_dict[colorr]["900"])

        color = colorr

    def on_pre_enter(self, *args):
        screens = "main"
        if color != pickle.load(open("color.pickle", "rb")):
            for i in self.children:
                if "MDScrollView" not in str(i):
                    setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
        for i2 in self.scrollvieww.children[0].children:
            setattr(i2.children[1], 'line_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
            setattr(i2.children[0], 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    def filters_window(self, b):
        self.manager.current = "filter"
        self.manager.get_screen("filter").filters_list = self.filters_list

    def intervals_window(self, b):
        self.manager.current = "intervals"
        self.manager.get_screen("intervals").intervals_list = self.intervals_list


class MainScreen(MDScreen):
    def __init__(self, **kwargs):
        super(MainScreen, self).__init__(**kwargs)
        self.layout = GridLayout(cols=1, size_hint_y=None, row_default_height=Window.width, spacing="300dp")
        self.layout.bind(minimum_height=self.layout.setter("height"))
        self.timeout = []
        self.last_input = ""
        try:
            self.deadline = [int(i) for i in list(pickle.load(open("intervals.pickle", 'rb')).values())]
        except:
            self.deadline = [480, 2880, 8640]
            pickle.dump({0: 480, 1: 2880, 2: 8640}, open("intervals.pickle", 'wb'))
        if len(self.deadline) == 0:
            self.deadline = [480, 2880, 8640]
            pickle.dump({0: 480, 1: 2880, 2: 8640}, open("intervals.pickle", 'wb'))
        self.now = [datetime.now().year, datetime.now().month, datetime.now().day, datetime.now().hour,
                    datetime.now().minute]  # список с настоящим временем
        self.buttons = []

        try:
            self.matrix = pickle.load(open(matrix_file, "rb"))
        except:
            pickle.dump({}, open(matrix_file, 'wb'))
            self.matrix = pickle.load(open(matrix_file, "rb"))

        self.matrix_keys = self.matrix.keys()
        self.matrix_values = self.matrix.values()
        self.list_layout = MDList()
        self.scrollvieww = ScrollView(pos_hint={'center_x': .5, 'center_y': .5}, size_hint=(1, 0.8))
        self.scrollvieww.add_widget(self.list_layout)
        self.add_widget(self.scrollvieww)
        self.close = 0
        self.s2 = 0
        self.filter = ""
        self.current_menu_item = ""

        self.learn_list = []

        self.list_dict = {}

        # layouts
        KV = """
MDFloatLayout:
    pos_hint:{"center_x": .5, "center_y": .95}
    size_hint:(1,0.1)
"""
        self.gui_layout = Builder.load_string(KV)
        KV2 = """
MDFloatLayout:
    pos_hint:{"center_x": .5, "center_y": .05}
    size_hint:(1,0.1)
            """
        self.gui_layout2 = Builder.load_string(KV2)
        self.gui_layout2.md_bg_color = color_dict[color]["900"]

        # upper_section
        self.text_input = MDTextField(
            size_hint=(.6, None),
            hint_text="искать...",
            pos_hint={"center_x": 0.5, "center_y": 0.5},
            line_color_focus="white",
            on_text_validate=self.on_check_text,
            text_color_focus="white",

        )
        # lower_section
        self.settings_button = CustomButton(
            theme_icon_color="Custom",
            icon_color="#311021",
            on_press=self.settings,
            pos_hint={"center_x": .9, "center_y": 0.915},
        )
        self.settings_button.add_widget(MDIcon(icon="dots-horizontal"))
        # filters
        self.filter_btn = CustomButton(
            icon='filter-outline',

            pos_hint={"center_x": 0.1, 'center_y': self.settings_button.pos_hint["center_y"]},
        )
        self.filter_btn.add_widget(MDIcon(icon="filter-outline"))
        # settings

        self.add_btn = CustomButton(

            theme_icon_color="Custom",
            icon_color="#311021",
            on_press=self.on_add,
            pos_hint={"center_x": self.settings_button.pos_hint["center_x"],
                      "center_y": self.settings_button.pos_hint["center_y"]},
            opacity=0,
        )
        self.add_btn.add_widget(MDIcon(icon="new-box"))
        self.settings_button2 = CustomButton(

            theme_icon_color="Custom",
            icon_color="#311021",
            on_press=self.on_settings,
            pos_hint={"center_x": self.settings_button.pos_hint["center_x"],
                      "center_y": self.settings_button.pos_hint["center_y"]},
            opacity=0,
        )
        self.settings_button2.add_widget(MDIcon(icon="wrench", ))
        self.exit_btn = CustomButton(
            theme_icon_color="Custom",
            icon_color="#311021",
            on_press=self.on_exit,
            pos_hint={"center_x": self.settings_button.pos_hint["center_x"],
                      "center_y": self.settings_button.pos_hint["center_y"]},
            opacity=0
        )
        self.exit_btn.add_widget(MDIcon(icon="power", ))
        self.next_button = CustomButton(
            theme_icon_color="Custom",
            icon_color="#311021",

            pos_hint={"center_x": self.settings_button.pos_hint["center_x"],
                      "center_y": 1 - self.settings_button.pos_hint["center_y"]},
            on_press=self.on_next_page
        )
        self.next_button.add_widget(MDIcon(icon="arrow-right-bold", ))

        self.previous_button = CustomButton(
            theme_icon_color="Custom",
            icon_color="#311021",

            pos_hint={"center_x": 1 - self.settings_button.pos_hint["center_x"],
                      "center_y": 1 - self.settings_button.pos_hint["center_y"]},
            on_press=self.on_previous_page
        )
        self.previous_button.add_widget(MDIcon(icon="arrow-left-bold", ))

        Clock.schedule_once(lambda dt: self.canvas.ask_update(), 0)
        self.add_widget(self.gui_layout)
        self.add_widget(self.gui_layout2)
        self.gui_layout.add_widget(self.text_input)
        self.add_widget(self.settings_button2)
        self.add_widget(self.exit_btn)
        self.add_widget(self.add_btn)
        self.add_widget(self.settings_button)
        self.add_widget(self.filter_btn)
        self.add_widget(self.next_button)
        self.add_widget(self.previous_button)
        self.button_layout = RelativeLayout()
        self.check()
        self.on = 0
        self.s = 0
        self.s3 = 0
        self.limit = limit
        self.button_list = []
        self.current_buttons = 0
        self.previous_buttons = 0
        self.once = 1
        self.current_visible_buttons = []

    def on_update_vb(self, b=None):
        limit = pickle.load(open("LIMIT.pickle", 'rb'))
        while self.limit < len(self.list_layout.children):
            self.list_layout.remove_widget(self.list_layout.children[0])
        if self.current_buttons + limit <= len(self.button_list):
            if len(self.current_visible_buttons) < len(self.button_list):
                self.current_visible_buttons = self.button_list[
                                               self.current_buttons:self.current_buttons + limit]
            else:
                self.current_visible_buttons = self.button_list

        else:
            print(111111, self.current_buttons, len(self.button_list))
            if self.current_buttons <= len(self.button_list):
                self.current_visible_buttons = self.button_list[self.current_buttons:]
                while len(self.current_visible_buttons) < len(self.list_layout.children):
                    self.list_layout.remove_widget(self.list_layout.children[0])
            else:
                self.current_buttons = 0
                self.limit = pickle.load(open("LIMIT.pickle", 'rb'))
                self.on_update_vb()

    def on_check_text(self, b):
        self.update_search_results(filters=b.text)

    def on_refresh(self, b=False):
        while len(self.current_visible_buttons) > len(self.list_layout.children):
            self.add_button(matrix_item=self.button_list[0][0], first_sentence=self.button_list[0][1], nothing=True)

        for k, i in zip(reversed(self.current_visible_buttons), range(pickle.load(open("LIMIT.pickle", 'rb')))):
            self.list_layout.children[i].text = str(k[0]) + " " + k[1]
            setattr(self.list_layout.children[i], 'on_press',
                    lambda x=k[0]: self.on_edit(x))

            self.list_layout.children[i].children[0].children[0].on_press = lambda z=k, x=i,y=self.list_layout.children[i]: self.delete_button(
                matrix_item=z[0], list_item=x, button=y)
            print(list(self.list_dict.keys()), 33333)
            self.list_dict[k[0]] = self.list_dict.pop(list(self.list_dict.keys())[0])

    def on_next_page(self, b=False, freeze=False):
        limit = pickle.load(open("LIMIT.pickle", 'rb'))
        self.current_buttons += limit if self.current_buttons + limit < len(self.button_list) else 0
        self.on_update_vb()
        self.on_refresh()

    def on_previous_page(self, b):
        limit = pickle.load(open("LIMIT.pickle", 'rb'))
        if self.current_buttons - pickle.load(open("LIMIT.pickle", 'rb')) >= 0:
            self.current_buttons -= pickle.load(open("LIMIT.pickle", 'rb'))
        else:
            self.current_buttons = 0
        self.on_update_vb()

        self.on_refresh()

    def on_settings(self, b):
        self.manager.get_screen("settings").filters_list = self.menu_items
        self.manager.transition.direction = 'left'
        self.manager.current = 'settings'

    def settings(self, a):
        if self.s3:
            animation = Animation(
                opacity=0,
                pos_hint={"center_y": self.settings_button.pos_hint["center_y"]},
                duration=0.5,
                t=main_animation)
            animation.start(self.settings_button2)
            animation.start(self.add_btn)
            animation.start(self.exit_btn)
            self.s3 = 0
        elif self.s3 == 0:
            if self.close:
                self.filters(None)
            k = self.settings_button.pos_hint["center_y"]

            animation2 = Animation(
                opacity=1,
                pos_hint={"center_y": k - kok},
                duration=0.4,
                t=main_animation).start(self.settings_button2)

            delete_animation1 = Animation(
                opacity=1,
                pos_hint={"center_y": k - kok * 2},
                duration=0.6,
                t=main_animation).start(self.add_btn)
            set_animation = Animation(
                opacity=1,
                pos_hint={"center_y": k - kok * 3},
                duration=0.8,
                t=main_animation).start(self.exit_btn)
            self.s3 += 1

    def apply_filters(self, a):
        self.menu_items.append(self.text_input2.text)
        self.menu.items = [{
            "text": f"{i}",
            "viewclass": "OneLineListItem",
            "on_release": lambda x=f"Item {i}", i=i: self.update_search_results(filters=i),
        } for i in self.menu_items]

    def delete_filters(self, a):
        self.menu_items.remove(self.delete_filter_input.text)
        self.menu.items = [{
            "text": f"{i}",
            "viewclass": "OneLineListItem",
            "on_release": lambda x=f"Item {i}", i=i: self.update_search_results(filters=i),
        } for i in self.menu_items]

    def add_filter(self, a):
        if self.s2:
            self.delete_filter(None)
            self.s2 = 0
        if self.s:
            anim = Animation(duration=0.3, size_hint=(-.4, 0))
            anim &= Animation(pos_hint=self.add_filter_button.pos_hint)
            anim.start(self.add_filter_layout)

            self.add_filter_layout.disabled = True
            self.s = 0
        else:
            self.add_filter_layout.disabled = False
            anim = Animation(duration=0.3, size_hint=(4, 0))
            anim &= Animation(pos_hint={"center_x": .25})
            anim.start(self.add_filter_layout)
            self.s += 1

    def delete_filter(self, a):
        if self.s:
            self.add_filter(None)
            self.s = 0
        if self.s2:
            Animation(duration=0.3, opacity=0).start(self.delete_filter_layout)
            self.delete_filter_layout.disabled = True
            self.s2 = 0
        else:
            self.delete_filter_layout.disabled = False
            Animation(duration=0.3, opacity=1).start(self.delete_filter_layout)
            self.s2 += 1

    def filters(self, a):
        self.s = 0
        self.s2 = 0
        if self.close:
            animation = Animation(
                opacity=0,
                pos_hint=self.filter_settings.pos_hint,
                duration=0.5,
                t=main_animation)
            animation2 = Animation(
                opacity=0,
                duration=0.5,
                t=main_animation)
            animation.start(self.add_filter_button)
            animation.start(self.text_button)
            animation.start(self.delete_filter_button)
            self.add_filter_layout.disabled = True
            self.delete_filter_layout.disabled = True

            self.close = 0

        elif self.close == 0:
            if self.s3:
                self.settings(None)

            animation4 = Animation(
                opacity=1,
                pos_hint={"center_y": 0.9 - kok * 2},
                duration=0.6,
                t=main_animation)
            animation4.start(self.add_filter_button)
            animation4.start(self.text_button)
            animation4.start(self.add_filter_layout)
            delete_animation1 = Animation(
                opacity=1,
                pos_hint={"center_y": 0.9 - kok * 1},
                duration=0.8,
                t=main_animation)
            delete_animation1.start(self.delete_filter_button)
            self.delete_filter_layout.disabled = False
            self.close += 1

    def open_menu(self, a):
        self.menu.open()

    def on_pre_enter(self, *args):

        for i in self.children:
            if "MDScrollView" not in str(i):
                setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
        setattr(self.text_input, 'line_color_normal', color_dict[pickle.load(open("color.pickle", "rb"))]["600"])
        setattr(self.text_input, 'hint_text_color_normal', color_dict[pickle.load(open("color.pickle", "rb"))]["300"])
        setattr(self.text_input, 'hint_text_color_focus', color_dict[pickle.load(open("color.pickle", "rb"))]["300"])
        try:
            self.menu_items = pickle.load(open("filters.pickle", "rb"))
        except:

            self.menu_items = filters_list
            pickle.dump(self.menu_items, open("filters.pickle", 'wb'))

        self.menu = MDDropdownMenu(
            caller=self.filter_btn,
            items=[
                {
                    "text": f"{self.menu_items[i]}",
                    "viewclass": "OneLineListItem",
                    "on_release": lambda x=f"Item {self.menu_items[i]}",
                                         i=self.menu_items[i]: self.update_search_results(filters=i),
                } for i in self.menu_items
            ],
            width_mult=4,
        )
        self.filter_btn.bind(on_release=self.open_menu)

        self.matrix = pickle.load(open(matrix_file, 'rb'))
        for child in self.children:
            if child.__class__.__name__ == 'MDRaisedButton':
                child.elevation_normal = 2
        self.update_search_results(filters=self.filter)

    def update_button(self, matrix_item, button_dict):
        if self.matrix[matrix_item]['text']:
            button_dict[matrix_item].text = f"{self.matrix[matrix_item]['id']} {self.matrix[matrix_item]['text']}"
            if not self.matrix[matrix_item]["learn"]:
                button_dict[matrix_item].md_bg_color = color_dict[color]
        else:
            button_dict[matrix_item].text = f"AAAAA "

    def save_matrix(self):
        pickle.dump(self.matrix, open(matrix_file, 'wb'))

    def check(self):
        for i in self.matrix_keys:

            self.time = 0
            pickle.dump(self.time, open("time.pickle", 'wb'))
            self.num = self.matrix[i]['date']
            self.num = [self.now[i] - self.num[i] for i in
                        range(len(self.now))]  # список с значением времени - нынешнее время
            self.time += self.num[0] * 525960  # переводим года в минуты...   |
            self.time += self.num[1] * 43800  # переводим месяцы в минуты...   |
            self.time += self.num[2] * 1440  # переводим дни в минуты...         | - вот это
            self.time += self.num[3] * 60  # переводим часы в минуты...        |
            self.time += self.num[4] * 1  # переводим минуты в минуты...      |
            if self.time >= self.matrix[i]['time']:  # если время больше или равн о значению # времени блока
                print(self.time, self.matrix[i]["time"])
                try:
                    self.deadline[self.deadline.index(self.matrix[i]['time'])]
                except:
                    error_time = self.matrix[i]['time']
                    min_ = 999999999999999999999999999
                    index_ = None
                    for k in range(len(self.deadline)):

                        if abs(self.deadline[k] - error_time) < min_:
                            min_ = abs(self.deadline[k] - error_time)
                            index_ = k
                    print(self.deadline)
                    self.matrix[i]['time'] = self.deadline[index_]
                if self.deadline[self.deadline.index(self.matrix[i]['time'])] >= self.deadline[
                    -1]:  # если значение времени уже максимальное то:
                    pass
                else:
                    self.matrix[i]['time'] = self.deadline[self.deadline.index(self.matrix[i][
                                                                                   'time']) + 1]  # задаём переменной x значение списка deadline, которое идёт за значением, присвоенном до этого (было 480 стало 2880, к примеру)
                self.matrix[i]['date'] = self.now
                self.timeout.append(self.matrix[i])
        for i in self.timeout:
            self.matrix[i['id']]['learn'] = True
        pickle.dump(self.matrix, open(matrix_file, "wb"))

    def delete_button(self, matrix_item=0, button=False, list_item=0, ):
        print(matrix_item, list_item)
        self.list_layout.remove_widget(button)

        del self.matrix[matrix_item]
        self.save_matrix()
        self.update_search_results(filters=self.filter)
        self.on_update_vb()
        self.on_refresh()

    def add_button(self, matrix_item, first_sentence, nothing=False):

        KV = """
IconRightWidget:
    icon: "minus"
                """

        list_item = OneLineAvatarIconListItem(
            text=str(self.matrix[matrix_item]['id']) + " " + str(first_sentence),
            opacity=1)
        minus_icon = Builder.load_string(KV)
        minus_icon.on_press = lambda *args: self.delete_button(matrix_item, list_item)
        list_item.add_widget(minus_icon)

        self.list_dict[matrix_item] = list_item
        # self.button_layout.add_widget(self.button_dict[matrix_item])
        self.list_layout.add_widget(list_item)

    def update_search_results(self, dt=0, filters=""):

        if filters:
            self.filter_btn.text = filters
            self.filter = filters
        text = self.text_input.text
        self.matrix = pickle.load(open(matrix_file, 'rb'))  # без pickle не видит последний элемент
        if len(text) > 0 or filters:  # filters отсеить надо, а то любой фильтр открывает часть кода этого
            self.button_list = []
            for i, k in zip(self.matrix, range(len(self.matrix))):
                if filters == 'учить':
                    first_sentence = self.matrix[i]['text'][0:50]
                    if self.matrix[i]['learn']:
                        print(self.matrix[i]["id"])
                        # if self.matrix[i]["id"] not in self.list_dict.keys():
                        self.button_list.append((i, first_sentence))

                elif text in self.matrix[i]['text'] and text != "" or filters == "все" or filters in self.matrix[i][
                    'text'] and filters != "":
                    editor = self.matrix[i]
                    first_sentence = editor['text'][0:50]

                    self.button_list.append((i, first_sentence))
                else:
                    if self.matrix[i]["id"] in self.list_dict.keys():
                        self.list_layout.remove_widget(self.list_dict[self.matrix[i]["id"]])
                        del self.list_dict[self.matrix[i]["id"]]
                self.last_input = text

            self.on_update_vb()

            if len(self.list_layout.children) == 0:
                for ik in self.current_visible_buttons:
                    print(ik[0], 44444)
                    self.add_button(ik[0], ik[1])

            self.on_refresh()

    def on_add(self, instance):
        if list(self.matrix.keys()):

            editor_id = max(list(self.matrix.keys())) + 1
        else:
            editor_id = 1
        self.show_editor(editor_id, text=0, age=0)

    def on_exit(self):
        MyApp.stop()

    def on_edit(self, button, learn=None):
        if learn:
            self.add_widget(self.over)
        editor_screen = self.manager.get_screen('editor')
        print("AAAAAAAAA", button)
        editor_id = int(button)  # Получаем первый символ для определения номера кнопки
        editor_screen.idd = editor_id
        if self.matrix[editor_id]:
            editor_screen.textt_input.text = self.matrix[editor_id]['text']
        editor_screen.list_dict = self.list_dict
        text = self.matrix[editor_id]["text"]
        self.show_editor(editor_id, text=1)

        pickle.dump(editor_id, open('id.pickle', 'wb'))

    def save_matrix(self):
        with open(matrix_file, "wb") as file:
            pickle.dump(self.matrix, file)

    def show_editor(self, editor_id, text, age=1):
        print("BBBBBBBBBBb")
        if text:
            pickle.dump(editor_id, open('id.pickle', 'wb'))
        if self.matrix and age:
            if self.matrix[editor_id]["learn"]:
                self.manager.get_screen("editor").over = 1
        self.manager.get_screen("editor").age = age
        self.manager.get_screen("editor").idd = editor_id

        self.manager.transition.direction = 'left'
        self.manager.current = 'editor'


class EditorScreen(MDScreen):
    def __init__(self, text=0, launch=0, **kwargs):
        super(EditorScreen, self).__init__(**kwargs)
        self.ms = MainScreen()

        self.layout = GridLayout(cols=1, spacing=1, size_hint_y=None, row_default_height=Window.width * .5)
        KV = """
MDFloatLayout:
    pos_hint:{"center_x": .5, "center_y": .05}
    size_hint:(1,0.1)
        """
        self.gui_layout = Builder.load_string(KV)
        self.gui_layout.md_bg_color = color_dict[color]["900"]
        self.sc = Scatter(do_rotation=False, auto_bring_to_front=False)
        self.layout.bind(minimum_height=self.layout.setter("height"))

        self.idd = 0
        self.over = 0
        self.age = 1
        self.text = text
        self.s = 0
        self.close = 0
        self.list_dict = {}
        self.matrix = pickle.load(open(matrix_file, "rb"))

        if self.matrix:
            self.matrix_keys = self.matrix.keys()
            self.matrix_values = self.matrix.values()
        self.launch = launch
        self.scrollview = ScrollView()
        self.scrollview.add_widget(self.layout)

        self.add_widget(self.scrollview)
        self.add_widget(self.gui_layout)
        self.image_list_current = []

        self.settings_button = CustomButton(
            pos_hint={'right': 0.99, "center_y": 0.1},
            on_press=self.show_buttons
        )
        self.settings_button.add_widget(MDIcon(icon="wrench"))
        self.file_button = CustomButton(
            pos_hint=self.settings_button.pos_hint,
            on_press=lambda iw: self.file_chooser.show(pickle.load(open("PATH.pickle", 'rb'))),

        )
        self.file_button.add_widget(MDIcon(icon="file-image-plus-outline"))
        self.camera_button = CustomButton(
            pos_hint=self.settings_button.pos_hint,
            on_press=self.capture,

        )
        self.camera_button.add_widget(MDIcon(icon="camera"))
        self.mp3_button = CustomButton(
            pos_hint=self.settings_button.pos_hint,
            on_press=self.on_mp3,

        )
        self.mp3_button.add_widget(MDIcon(icon="music-note"))
        self.textt_input = TextInput()
        self.text_mode_button = CustomButton(
            pos_hint=self.settings_button.pos_hint,
            on_press=self.on_text,
        )
        self.text_mode_button.add_widget(MDIcon(icon="note-text-outline"))
        self.back_button = CustomButton(
            icon="keyboard-backspace",
            pos_hint={'center_x': 0.1, "center_y": 0.1},
            on_press=lambda text: self.on_main(text=self.textt_input.text,
                                               editor_id=self.idd),
        )
        self.back_button.add_widget(MDIcon(icon="keyboard-backspace"))
        self.add_widget(self.mp3_button)
        self.add_widget(self.camera_button)

        self.add_widget(self.back_button)
        self.add_widget(self.text_mode_button)
        self.add_widget(self.file_button)

        self.file_chooser = MDFileManager(
            exit_manager=self.exit_manager,
            select_path=self.on_file_selection,
            preview=True)
        self.add_widget(self.settings_button)

        self.overlearn = 0
        self.launch = launch

    def on_pre_leave(self, *args):
        pickle.dump(self.matrix, open(matrix_file, 'wb'))
        if self.list_dict:
            self.update_button(self.idd)

    def on_text(self, b):
        self.manager.current = "text"

    def on_mp3(self, b):
        self.manager.current = "mp3"

    def capture(self, b):
        self.manager.current = "camera"

    def change_spacing(self, instance, value):
        self.layout.spacing = value * 2

    def show_buttons(self, a):

        if self.s:
            animation = Animation(
                opacity=0,
                pos_hint={"center_y": self.settings_button.pos_hint["center_y"]},
                duration=0.5,
                t=main_animation)
            animation.start(self.file_button)
            animation.start(self.text_mode_button)
            animation.start(self.camera_button)
            animation.start(self.mp3_button)
            self.s = 0

        elif self.s == 0:

            file_button_animation = Animation(
                opacity=1,
                pos_hint={"center_y": 0.2},
                duration=0.5,
                t=main_animation)
            file_button_animation.start(self.file_button)
            button_text_animation = Animation(
                opacity=1,
                pos_hint={"center_y": 0.3},
                duration=0.6,
                t=main_animation)
            button_text_animation.start(self.text_mode_button)
            camera_animation = Animation(
                opacity=1,
                pos_hint={"center_y": 0.4},
                duration=0.7,
                t=main_animation)
            camera_animation.start(self.camera_button)
            mp3_animation = Animation(
                opacity=1,
                pos_hint={"center_y": 0.5},
                duration=0.8,
                t=main_animation)
            mp3_animation.start(self.mp3_button)
            self.s += 1

    def exit_manager(self, *args):
        self.file_chooser.close()

    def on_enter(self):
        self.matrix = pickle.load(open(matrix_file, 'rb'))

    def on_pre_enter(self):
        screens = "main"
        self.matrix = pickle.load(open(matrix_file, 'rb'))
        # self.overlearn = 0
        if self.idd not in list(self.matrix.keys()):
            self.matrix[self.idd] = {
                "id": self.idd,
                "date": [datetime.now().year, datetime.now().month, datetime.now().day, datetime.now().hour,
                         datetime.now().minute, ],
                "time": pickle.load(open("intervals.pickle", 'rb'))[
                    list(pickle.load(open("intervals.pickle", 'rb')).keys())[0]],
                "text": "",
                "image": [],
                "learn": False
            }
        self.on_load_images(self.idd)
        if self.over:
            self.over_learn = CustomButton(
                pos_hint={'center_x': 0.3, "center_y": .1},
            )
            self.over_learn.add_widget(MDIcon(icon="note-check-outline"))
            self.over_learn.bind(on_press=lambda text: self.on_main(text=self.textt_input.text,
                                                                    editor_id=self.idd, over=1))
            self.add_widget(self.over_learn)

        pickle.dump(self.matrix, open(matrix_file, 'wb'))
        if color != pickle.load(open("color.pickle", "rb")):
            for i in self.children:
                if "MDScrollView" not in str(i):
                    setattr(i, 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
        for i2 in self.scrollview.children[0].children:
            setattr(i2.children[1], 'line_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])
            setattr(i2.children[0], 'md_bg_color', color_dict[pickle.load(open("color.pickle", "rb"))]["900"])

    from functools import partial
    def delete_image(self, image, block):
        del self.matrix[self.idd]["image"][self.matrix[self.idd]["image"].index(image)]
        del image_list[self.idd][image]
        self.layout.remove_widget(block)
        pickle.dump(self.matrix, open(matrix_file, 'wb'))

    def on_file_selection(self, path):
        self.image = path
        if self.image:
            self.matrix[self.idd]["image"].append(path)

            im = MDRectangleFlatButton(
                on_press=self.spotlight,
                size_hint=(1, 1))
            im.add_widget(FitImage(
                source=path))
            self.xox = CustomButton(
                pos_hint={'center_x': .9, 'center_y': .9},
            )
            self.page = MDRelativeLayout(
                line_color=(0, 0, 0, 1),
                size_hint=im.size_hint, )
            self.xox.add_widget(MDIcon(icon="close-thick"))
            self.xox.bind(on_release=lambda x, image=path, button=im: self.delete_image(image, im))

            self.page.add_widget(im)
            self.page.add_widget(self.xox)
            self.layout.add_widget(self.page)
            image_list[path] = im
            pickle.dump(self.matrix, open(matrix_file, "wb"))

    def on_load_images(self, id):
        self.layout.clear_widgets()
        if id not in list(image_list.keys()):

            image_list[id] = {}
            for i33 in self.matrix[id]["image"]:
                im = MDRectangleFlatButton(
                    on_press=lambda x, i=i33: self.spotlight(x, i),
                    size_hint=(.99, .99),
                    pos_hint={"center_x": .5, "center_y": .5})
                image = FitImage(source=i33)
                im.add_widget(image)
                self.xox = MDFillRoundFlatButton(
                    pos_hint={'center_x': .9, 'center_y': .9},
                    line_width=4 * line_size,  # задаем ширину обводки
                    _radius=20,
                    line_color=(0, 0, 0, 1)
                )
                self.page = MDRelativeLayout()

                self.xox.add_widget(MDIcon(icon="close-thick"))
                self.xox.bind(on_release=lambda x, image=i33, button=self.page: self.delete_image(image, button))
                self.page.add_widget(im)
                self.page.add_widget(self.xox)
                self.layout.add_widget(self.page)
                image_list[id][i33] = self.page
        else:
            values = list(image_list[id].values())
            keys = list(image_list[id].keys())
            for i33 in range(len(list(image_list[id].values()))):
                if values[i33] == None:
                    im = MDRectangleFlatButton(
                        on_press=lambda x, i=keys[i33]: self.spotlight(x, i),
                        size_hint=(.99, .99),
                        pos_hint={"center_x": .5, "center_y": .5})
                    image = FitImage(source=keys[i33])
                    im.add_widget(image)
                    self.xox = MDFillRoundFlatButton(
                        pos_hint={'center_x': .9, 'center_y': .9},
                        line_width=4 * line_size,  # задаем ширину обводки
                        _radius=20,
                        line_color=(0, 0, 0, 1)
                    )
                    self.page = MDRelativeLayout()

                    self.xox.add_widget(MDIcon(icon="close-thick"))
                    self.xox.bind(
                        on_release=lambda x, image=keys[i33], button=self.page: self.delete_image(image, button))
                    self.page.add_widget(im)
                    self.page.add_widget(self.xox)
                    image_list[id][keys[i33]] = self.page
                self.layout.add_widget(list(image_list[id].values())[i33])

    def spotlight(self, b, image):
        self.gray = MDBoxLayout(md_bg_color=(128, 128, 128, .5))
        self.add_widget(self.gray)
        if not self.sc.children:
            im = Image(source=image, size=(Window.width, Window.height))
            self.close_button = MDFillRoundFlatButton(
                pos_hint={'center_x': .85, 'center_y': .90},
                line_width=4 * line_size,  # задаем ширину обводки
                line_color=(0, 0, 0, 1),
                _radius=20,

            )
            self.close_button.md_bg_color = color_dict[color]["900"]
            self.close_button.add_widget(MDIcon(icon="close-thick"))
            self.close_button.bind(on_release=self.close_spotlight)

            self.sc.add_widget(im)
            if self.sc not in self.children:
                self.add_widget(self.sc)
                self.add_widget(self.close_button)
            for i in self.children:
                i.disabled = True
                if i == self.close_button:
                    self.close_button.disabled = False
                if i == self.sc:
                    self.sc.disabled = False

    def close_spotlight(self, b):
        self.sc.clear_widgets()
        self.remove_widget(self.gray)
        for i in self.children:
            i.disabled = False
        self.remove_widget(self.close_button)
        self.remove_widget(self.sc)

    def update_button(self, matrix_item):
        self.matrix = pickle.load(open(matrix_file, 'rb'))

        if self.matrix[matrix_item]['text'] and matrix_item in self.list_dict.keys():
            self.list_dict[matrix_item].text = f"{self.matrix[matrix_item]['id']} {self.matrix[matrix_item]['text']}"
            if not self.matrix[matrix_item]["learn"]:
                self.list_dict[matrix_item].md_bg_color = color_dict[color]

    def on_main(self, text, editor_id, over=0):
        if over:
            self.matrix[editor_id]['learn'] = False
            pickle.dump(self.matrix, open(matrix_file, 'wb'))
            # nums = self.manager.get_screen("main").current_buttons

            # self.manager.get_screen("main").list_layout.remove_widget(self.manager.get_screen("main").list_dict[editor_id])

        self.manager.transition.direction = 'up'
        self.textt_input.text = ""

        self.sc.clear_widgets()
        self.manager.current = "main"


class MyApp(MDApp):
    def build(self):
        global sm, color
        sm = MDScreenManager()
        self.theme_cls.theme_style_switch_animation = True
        self.theme_cls.theme_style = pickle.load(open("theme.pickle", 'rb'))
        self.theme_cls.primary_palette = "Blue"
        color = self.theme_cls.primary_palette
        self.theme_cls.material_style = "M3"
        sm.add_widget(MainScreen(name="main"))
        sm.add_widget(EditorScreen(name="editor"))
        sm.add_widget(Text_Screen(name="text"))
        sm.add_widget(SettingsScreen(name="settings"))
        #sm.add_widget(CameraClick(name="camera"))
        sm.add_widget(FilterSettings(name="filter"))
        sm.add_widget(IntervalsScreen(name="intervals"))

        sm.add_widget(Mp3Screen(name="mp3"))
        sm.current = "main"
        return sm

    def switch_theme_style(self, *args):
        self.theme_cls.theme_style = (
            "Dark" if self.theme_cls.theme_style == "Light" else "Light"
        )
        pickle.dump(self.theme_cls.theme_style, open("theme.pickle", 'wb'))


if __name__ == "__main__":
    MyApp().run()

