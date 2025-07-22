# %%
import json
from pylatex import Table, Document, Tabular, MultiColumn
from pylatex import Package, Command
from pdf2image import convert_from_path
import os

def format_value(value):
    if isinstance(value, bool):
        return "\\checkmark" if value else ""
    return str(value)

# Load the JSON data
with open("~/artisan/evaluation/filtered.json", "r") as f:
    papers = json.load(f)

# Step 1: Check all paper pdfs exist
papers_dir = "~/artisan/evaluation/papers"
for paper in papers:
    pdf_path = os.path.join(papers_dir, f"{paper['id']}.pdf")
    assert os.path.isfile(pdf_path), pdf_path

# Step 2: Check all docker images exist

# Step 3: Check all tables exist

# Step 4: Check all figures exist

# Step 5: Check all ground truth scripts exist

# %%

# Prepare the data for tabulation
table_data = []
headers = ["Paper", "OpenHands(T)", "OpenHands(F)", "OpenHands(T+F)", "Artisan(T)", "Artisan(F)", "Artisan(T+F)",]

for paper in papers:
    title = paper["title"][:20]
    # Placeholder data - replace with actual metrics if available
    # compute denominators
    denom_t = len(paper.get("table_filtered", []))
    denom_f = len(paper.get("figure_filtered", []))
    denom_tf = denom_t + denom_f

    # counts for OpenHands
    oh_t_count = len(paper.get("openhands_table_results", []))
    oh_f_count = len(paper.get("openhands_figure_results", []))
    oh_tf_count = oh_t_count + oh_f_count

    # counts for Artisan
    art_t_count = len(paper.get("artisan_table_results", []))
    art_f_count = len(paper.get("artisan_figure_results", []))
    art_tf_count = art_t_count + art_f_count

    # format as ratios
    openhands_t  = format_value(f"{oh_t_count}/{denom_t}")
    openhands_f  = format_value(f"{oh_f_count}/{denom_f}")
    openhands_tf = format_value(f"{oh_tf_count}/{denom_tf}")

    artisan_t    = format_value(f"{art_t_count}/{denom_t}")
    artisan_f    = format_value(f"{art_f_count}/{denom_f}")
    artisan_tf   = format_value(f"{art_tf_count}/{denom_tf}")

    table_data.append([title, openhands_t, openhands_f, openhands_tf, artisan_t, artisan_f, artisan_tf])

# Compute totals from the ratio strings in table_data
sum_nums = [0] * 6
sum_dens = [0] * 6
for row in table_data:
    for i in range(6):
        num, den = row[i+1].split('/')
        sum_nums[i] += int(num)
        sum_dens[i] += int(den)

# Build footer with aggregated ratios
footer = ['Total'] + [
    format_value(f"{sum_nums[i]}/{sum_dens[i]}")
    for i in range(6)
]
table_data.append(footer)

# Render the table using pylatex
doc = Document()
doc.packages.append(Package('booktabs'))
doc.packages.append(Package('geometry', options=['left=1cm','right=1cm']))
doc.packages.append(Package('float'))

column_spec = '|' + '|'.join('l' for _ in headers) + '|'

# Insert small summary table: only header and footer
with doc.create(Table(position='H')) as small_tablefloat:
    with doc.create(Tabular(column_spec)) as small_table:
        # Header rows
        small_table.append(Command('toprule'))
        small_table.add_row([
            'Paper',
            MultiColumn(3, align='c', data='OpenHands'),
            MultiColumn(3, align='c', data='Artisan')
        ])
        small_table.append(Command('midrule'))
        small_table.add_row([
            '',
            'T', 'F', 'T+F',
            'T', 'F', 'T+F'
        ])
        small_table.append(Command('midrule'))
        # Only the footer row
        small_table.add_row(table_data[-1])
        small_table.append(Command('bottomrule'))

with doc.create(Table(position='H')) as float_table:
    with doc.create(Tabular(column_spec)) as table:
        # Two-row header: group labels and sublabels
        table.append(Command('toprule'))
        table.add_row([
            'Paper',
            MultiColumn(3, align='c', data='OpenHands'),
            MultiColumn(3, align='c', data='Artisan')
        ])
        table.append(Command('midrule'))
        table.add_row([
            '',
            'T', 'F', 'T+F',
            'T', 'F', 'T+F'
        ])
        table.append(Command('midrule'))
        # Add data rows (excluding footer)
        for row in table_data[:-1]:
            table.add_row(row)
        # Footer row
        table.append(Command('midrule'))
        table.add_row(table_data[-1])
        table.append(Command('bottomrule'))

output_tex = doc.dumps()
print(output_tex)

# Generate PDF from LaTeX and convert to PNG
filepath_prefix = 'papers_table'
doc.generate_pdf(filepath_prefix, clean_tex=True)
