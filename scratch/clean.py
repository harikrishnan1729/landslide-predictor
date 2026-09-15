with open('README.md', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(" - load_system lews_physics.m :\, '- **lews_physics.m**:')
text = text.replace('ppredictive_dashboard`', '`matlab\npredictive_dashboard\n`')
text = text.replace('`run_tests`', '`matlab\nrun_tests\n`')
text = text.replace('`train_model`', '`matlab\ntrain_model\n`')
text = text.replace('`plot_results`', '`matlab\nplot_results\n`')

with open('README.md', 'w', encoding='utf-8') as f:
 f.write(text)
print('Cleaned up README.md')
