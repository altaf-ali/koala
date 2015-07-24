import logging
import os

import luigi

import utils.results
import utils.logger

class GenericTask(utils.logger.GenericLogger, luigi.Task):
    pipeline = luigi.Parameter(default=None)

    def __init__(self, *args, **kwargs):
        super(GenericTask, self).__init__(*args, **kwargs)

        # for top-level pipelines
        if not self.pipeline:
            self.pipeline = self

        self.results_folder = utils.results.Results.results_folder(self.pipeline.task_family)
        self.results = utils.results.Results(self, self.results_folder)

    def clean(self):
        map(lambda d: d.clean(), self.deps())

        # make sure it's a file and NOT a directory
        if self.output() and os.path.isfile(self.output().fn):
            self.logger.debug("removing " + self.output().fn)
            self.output().remove()

    def output(self):
        return self.results.target

    def set_results(self, data):
        self.results.update(data)

    def on_success(self):
        self.results.save('SUCCESS')
