import luigi

from tasks.generic import GenericTask
from pipelines.escalation import EscalationPipeline

class Main(GenericTask):
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

