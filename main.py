import luigi

from tasks.pipeline import Pipeline
from tasks.generic import GenericTask

from pipelines.escalation import EscalationPipeline

class TestTask(GenericTask):
    def run(self):
        print "running ", self.task_family

class Task_A(TestTask):
    def requires(self):
        return Task_B(self.pipeline)

class Task_B(TestTask):
    def requires(self):
        return Task_C(self.pipeline)

class Task_C(TestTask):
    pass

class Test_Pipeline(Pipeline):
    def complete(self):
        print "in Test_Pipeline.complete()"
        return super(Test_Pipeline, self).complete()

    def requires(self):
        return Task_A(pipeline=self)

class Main(Pipeline):
    def requires(self):
        pipelines = [
            EscalationPipeline()
        ]
        return pipelines

class Clean(luigi.Task):
    def complete(self):
        return False # forces clean to run

    def run(self):
        Main().clean()

if __name__ == "__main__":
    luigi.run()

