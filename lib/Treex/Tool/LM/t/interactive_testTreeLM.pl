#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

#use IO::Prompt; nějak to nezvládá utf8

use Treex::Tool::LM::Lemma;
use Treex::Tool::LM::TreeLM;
my $model = Treex::Tool::LM::TreeLM->new();

while (1){
    print "-------- Query---------\n";
    print 'Lg POS: ';  $_ = <>; chomp; my $uLg = $_ or last;
    print 'Ld POS: ';  $_ = <>; chomp; my $uLd = $_ or last;
    print 'Fd: ';      $_ = <>; chomp; my $Fd  = $_ or last;
    my $Lg = Treex::Tool::LM::Lemma->new($uLg);
    my $Ld = Treex::Tool::LM::Lemma->new($uLd);
    my $probLdFd_Lg = $model->get_prob_LdFd_given_Lg($Ld,$Fd,$Lg,1);
}
print "\n";