with open('README.md', 'r') as f:
    d = f.read()
d= d.replace('a`ppredictive_dashboard``', 'predictive_dashboard')
d= d.replace('load_system(\'lews_physics.m\')', 'lews_physics.m')
with open('README.md', 'w') as f:
    f.write(d)
print('Fixed!')