#!/usr/bin/env python3
import urwid

def on_submit(button, name_edit, age_edit):
    name = name_edit.edit_text
    age = age_edit.edit_text
    response.set_text(f"Hello {name}, you are {age} years old!")

# Create form fields
name_edit = urwid.Edit(caption="Name: ")
age_edit = urwid.Edit(caption="Age: ")

# Submit button
submit_button = urwid.Button("Submit")
urwid.connect_signal(submit_button, 'click', on_submit, user_args=[name_edit, age_edit])

# Response text
response = urwid.Text("")

# Pack everything into a pile (vertical layout)
form = urwid.Pile([
    name_edit,
    age_edit,
    urwid.Divider(),
    urwid.AttrMap(submit_button, None, focus_map='reversed'),
    urwid.Divider(),
    response
])

# Add padding
main = urwid.Padding(form, left=2, right=2)

# Add a frame (optional, for a title)
top = urwid.Filler(main, valign='top')

# Run the app
urwid.MainLoop(top, palette=[('reversed', 'standout', '')]).run()
