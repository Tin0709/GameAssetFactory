"""Native Blender regressions for reversible library focus; never saves the file.

Run with Blender --background --factory-startup Showcase.blend --python this_file.
"""
import copy
import json
import sys
import unittest
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gaf_animation_library as ui

WALK = 'Walk_ActionsStuff_Source_Test_v001'
RUN = 'Run_ActionsStuff_Source_Test_v001'
SEQUENCE = 'actions_stuff_directional_v001'
LABEL = 'Actions & Stuff Directional Input v001'
FOCUS = {'label': 'Actions & Stuff', 'entries': [
    {'kind': 'action', 'id': WALK}, {'kind': 'action', 'id': RUN},
    {'kind': 'review_sequence', 'id': SEQUENCE}]}


class LibraryFocusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not hasattr(bpy.types, 'GAF_PT_animation_library'):
            ui.register()
        ui.loaded(None)
        cls.home = bpy.data.scenes['ANIMATION_SHOWCASE']
        cls.snapshot = cls.home['gaf_manifest_snapshot']
        cls.original_index = cls.home.gaf_active_index
        cls.review = bpy.data.scenes['ASD_Directional_Review_v001']
        cls.review_entry = cls.review[ui.REVIEW_ENTRY]

    def setUp(self):
        bpy.context.window.scene = self.home
        data = json.loads(self.snapshot)
        data['library_focus'] = copy.deepcopy(FOCUS)
        data['review_sequences'][0]['status'] = 'approved'
        self.home['gaf_manifest_snapshot'] = json.dumps(data)
        self.entry = data['review_sequences'][0]
        self.review[ui.REVIEW_ENTRY] = json.dumps(self.entry)

    def tearDown(self):
        bpy.context.window.scene = self.home
        self.home['gaf_manifest_snapshot'] = self.snapshot
        self.review[ui.REVIEW_ENTRY] = self.review_entry
        if hasattr(self.home, 'gaf_show_archived'):
            self.home.gaf_show_archived = True
        self.home.gaf_active_index = self.original_index

    def require_focus(self):
        self.assertTrue(callable(getattr(ui, 'library_entries', None)),
                        'Library needs a reversible focused selection model')

    def test_default_selection_contains_exactly_two_actions_and_directional_sequence(self):
        self.require_focus()
        entries = ui.library_entries(self.home, show_archived=False)
        self.assertEqual([(e['kind'], e['label']) for e in entries], [
            ('action', WALK), ('action', RUN), ('review_sequence', LABEL)])
        self.assertEqual(entries[-1]['status'], 'approved')

    def test_archive_restores_every_registered_entry_without_removal(self):
        self.require_focus()
        before = [c.action for c in self.home.gaf_clips]
        entries = ui.library_entries(self.home, show_archived=True)
        self.assertEqual(len(entries), 38)
        self.assertEqual({e['id'] for e in entries if e['kind'] == 'action'}, set(before))
        self.assertEqual([c.action for c in self.home.gaf_clips], before)

    def test_hiding_archive_returns_hidden_selection_to_focus(self):
        self.assertTrue(hasattr(self.home, 'gaf_show_archived'),
                        'Archive visibility must persist as a scene property')
        self.home.gaf_show_archived = True
        self.home.gaf_active_index = 0
        self.assertEqual(bpy.data.objects[ui.RIG].animation_data.action.name,
                         self.home.gaf_clips[0].action)
        self.home.gaf_show_archived = False
        self.assertEqual(bpy.data.objects[ui.RIG].animation_data.action.name, WALK)
        self.assertEqual(len(self.home.gaf_clips), 37)

    def test_approved_research_remains_playable_but_cannot_be_production(self):
        try:
            self.assertEqual(ui.validate_review_sequence(self.entry), self.review)
        except ValueError as error:
            self.fail('Artistic approval must remain playable: ' + str(error))
        for change in [{'status': 'published'}, {'production_eligible': True},
                       {'research_only': False}, {'seamless_loop': True},
                       {'pose_action_sha256': 'tampered'}]:
            bad = dict(self.entry, **change)
            with self.assertRaises(ValueError):
                ui.validate_review_sequence(bad)

    def test_action_buttons_switch_from_sequence_using_existing_slots_and_timing(self):
        self.assertTrue(callable(getattr(ui, 'select_registered_action', None)),
                        'Focus buttons must use the existing activation mechanism')
        ui.open_review_sequence(bpy.context, SEQUENCE)
        self.assertEqual(bpy.context.scene, self.review)
        for action, end in [(RUN, 180), (WALK, 24)]:
            ui.select_registered_action(bpy.context, action)
            self.assertEqual(bpy.context.scene, self.home)
            rig = bpy.data.objects[ui.RIG]
            self.assertEqual(rig.animation_data.action.name, action)
            self.assertEqual(rig.animation_data.action_slot,
                             rig.animation_data.action.slots[0])
            self.assertEqual((self.home.frame_start, self.home.frame_end,
                              self.home.render.fps), (1, end, 30))
        self.assertFalse(bpy.context.screen.is_animation_playing)

    def test_sequence_panel_resolves_the_same_three_focus_entries(self):
        self.require_focus()
        entries = ui.library_entries(self.review, show_archived=False)
        self.assertEqual([e['label'] for e in entries], [WALK, RUN, LABEL])


suite = unittest.defaultTestLoader.loadTestsFromTestCase(LibraryFocusTests)
result = unittest.TextTestRunner(verbosity=2).run(suite)
if not result.wasSuccessful():
    raise AssertionError('Library focus regressions failed')
