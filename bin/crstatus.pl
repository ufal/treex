#!/usr/bin/env perl
# External analyzer of a *-cluster-run-* folder created by treex -p.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use List::Util qw(any);

my $crpath = shift(@ARGV);
if(!defined($crpath))
{
    die("Usage: 1 argument = path to *-cluster-run-* folder");
}
chdir($crpath) or die("Cannot enter folder '$crpath': $!");
opendir(DIR, '.') or die("Cannot read folder '$crpath': $!");
my @files = readdir(DIR);
closedir(DIR);
if(any {m/^total_number_of_documents$/} @files)
{
    my $n = `cat total_number_of_documents`;
    printf("Total number of documents = %d\n", $n);
}
# $CR/jobNNN.sh.oNNNNNNN ... standard output of each job as saved by the cluster
my @job_output_files = grep {m/^job\d+\.sh\.o\d+$/} (@files);
printf("Found output files of %d jobs.\n", scalar(@job_output_files));
# $CR/processing_info.log contains vital job-document pairing information
my @jobs_to_docs;
open(PI, 'processing_info.log') or die("Cannot read 'processing_info.log': $!");
while(<PI>)
{
    if(m/Client (\d+): next_filename; Assigned: (\d+)/)
    {
        my $ijob = $1;
        my $idoc = $2;
        my @new_doc_list = ($idoc);
        $jobs_to_docs[$ijob] = \@new_doc_list;
    }
    elsif(m/Client (\d+): next_filename; Finished (\d+); Assigned: (\d+)/)
    {
        my $ijob = $1;
        my $idoc = $2;
        my $jdoc = $3;
        if(scalar(@{$jobs_to_docs[$ijob]})==0)
        {
            die("Job $ijob finished document $idoc but there is no record that this job was ever assigned this document.");
        }
        my $known_last_doc = $jobs_to_docs[$ijob][-1];
        if($idoc != $known_last_doc)
        {
            die("Job $ijob finished document $idoc but it should have been processing document $known_last_doc.");
        }
        push(@{$jobs_to_docs[$ijob]}, $jdoc);
    }
    elsif(m/Client (\d+): next_filename; Finished (\d+)/)
    {
        my $ijob = $1;
        my $idoc = $2;
        if(scalar(@{$jobs_to_docs[$ijob]})==0)
        {
            die("Job $ijob finished document $idoc but there is no record that this job was ever assigned this document.");
        }
        my $known_last_doc = $jobs_to_docs[$ijob][-1];
        if($idoc != $known_last_doc)
        {
            die("Job $ijob finished document $idoc but it should have been processing document $known_last_doc.");
        }
        push(@{$jobs_to_docs[$ijob]}, '#');
    }
}
close(PI);
my $n_did_not_work = 0;
my $n_did_not_finish = 0;
my @unfinished_documents = ();
my @unfinished_jobs = ();
print("List of jobs and the documents processed in those jobs:\n");
for(my $ijob = 0; $ijob <= $#jobs_to_docs; $ijob++)
{
    if(scalar(@{$jobs_to_docs[$ijob]}) > 0)
    {
        if($jobs_to_docs[$ijob][-1] ne '#')
        {
            push(@unfinished_jobs, $ijob);
            push(@unfinished_documents, $jobs_to_docs[$ijob][-1]);
            push(@{$jobs_to_docs[$ijob]}, '.....?');
            $n_did_not_finish++;
        }
        my $docs = join(', ', @{$jobs_to_docs[$ijob]});
        print("  $ijob: $docs\n");
    }
    else
    {
        $n_did_not_work++;
    }
}
printf("There are %d jobs that were slow to start and did not get any documents.\n", $n_did_not_work);
printf("There are %d jobs that have not finished yet (or failed to report back).\n", $n_did_not_finish);
if($n_did_not_finish > 0)
{
    printf("The unfinished jobs are:      %s\n", join(', ', sort {$a <=> $b} (@unfinished_jobs)));
    printf("The unfinished documents are: %s\n", join(', ', sort {$a <=> $b} (@unfinished_documents)));
    print("Check the status of a seemingly unfinished job:\n");
    printf("  ls -al $crpath/status | grep job%03d\n", $unfinished_jobs[0]);
    print("Check the Treex part of the STDERR of a seemingly unfinished job:\n");
    # There is one stderr and one stdout file per document, e.g., doc0000060.stderr.
    printf("  cat $crpath/output__H.*__JOB__%d/*.stderr\n", $unfinished_jobs[0]);
}
