# Guidelines for contributing to Artisan-Bench

At its start, Artisan-Bench comprises of 60 tables collected from 23 papers.

We are open to adding more papers and tables to the benchmark with the contributions.

## Requirements for contributions

To add a new paper / task to the Artisan-Bench, three components are required:

- Paper with permissive copyrights for redistribution. This should be uploaded to [papers](./papers/) directory.
- Table transcribed to markdown table with permissive copyrights for redistribution. This should be uploaded to [tables](./tables/) directory.
- Ground truth script that reproduces the table from scratch. This should be uploaded to [scripts](./scripts/) directory.

There are few requirements ground truth scripts, which are up for discussion
- They should run without agent dependency from a base docker image (doehyunbaek1/artisan).
- They require the confirmation by the authors that this is valid full / last-mile reproduction.
