import os

import luigi

import utils.results
import utils.logger

class GenericTask(utils.logger.GenericLogger, luigi.Task):
    pipeline = luigi.Parameter()

    def __init__(self, *args, **kwargs):
        super(GenericTask, self).__init__(*args, **kwargs)

        # make sure pipline is actually a Pipline object
        from tasks.pipeline import Pipeline
        if not isinstance(self.pipeline, Pipeline):
            raise TypeError("unexpected type %s, expecting %s" % (type(self.pipeline), type(Pipeline)))

        self.results = utils.results.Results(self)

    @property
    def results_folder(self):
        return self.pipeline.results_folder

    def clean(self):
        map(lambda d: d.clean(), self.deps())

        # make sure it's a file and NOT a directory
        if self.output() and os.path.isfile(self.output().fn):
            self.logger.debug("removing " + self.output().fn)
            self.output().remove()

    def complete(self):
        #for dep in self.deps():
        #    if not dep.complete():
        #        return False
        if not all(map(lambda dep: dep.complete(), self.deps())):
            return False
        return super(GenericTask, self).complete()

    def output(self):
        return self.results.target

    def set_results(self, data):
        self.results.update(data)

    def on_success(self):
        self.results.save('SUCCESS')
