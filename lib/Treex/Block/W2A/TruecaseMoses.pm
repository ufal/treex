package Treex::Block::W2A::TruecaseMoses;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

use Treex::Core::Resource "require_file_from_share";

has model_dir => ( is => 'ro', isa => 'Str', default => 'data/models/truecaser' );

# TODO set model according to language?
has model => ( is => 'ro', isa => 'Str', default => 'truecase-model.en' );

has asr => ( is => 'ro', isa => 'Bool', default => 0 );

has best => ( is => 'rw', isa => 'HashRef', default => sub { {} } ); 

has known => ( is => 'rw', isa => 'HashRef', default => sub { {} } ); 

my %SENTENCE_END = ("."=>1,":"=>1,"?"=>1,"!"=>1);
my %DELAYED_SENTENCE_START = ("("=>1,"["=>1,"\""=>1,"'"=>1,"&apos;"=>1,"&quot;"=>1,"&#91;"=>1,"&#93;"=>1);

sub process_start {
    my ($self) = @_;

    my $path = require_file_from_share($self->model_dir . '/' . $self->model, ref($self));
    open my $file, '<:utf8', $path;
    while(<$file>) {
        my ($word,@OPTIONS) = split;
        $self->best->{ lc($word) } = $word;
        if ($self->asr == 0) {
            $self->known->{ $word } = 1;
            for(my $i=1;$i<$#OPTIONS;$i+=2) {
                $self->known->{ $OPTIONS[$i] } = 1;
            }
        }
    }
    close $file;

    return;
}

sub process_zone {
  my ($self, $zone) = @_;
  my @sentence;
  
  my ($WORD,$MARKUP) = split_xml($zone->sentence);
  my $sentence_start = 1;
  for(my $i=0;$i<=$#$WORD;$i++) {
    push @sentence, " " if $i && $$MARKUP[$i] eq '';
    push @sentence, $$MARKUP[$i];

    my ($word,$otherfactors);
    if ($$WORD[$i] =~ /^([^\|]+)(.*)/)
    {
	$word = $1;
	$otherfactors = $2;
    }
    else
    {
	$word = $$WORD[$i];
	$otherfactors = "";
    }
    if ($self->asr){
      $word = lc($word); #make sure ASR output is not uc
    }

    if ($sentence_start && defined($self->best->{lc($word)})) {
      push @sentence, $self->best->{lc($word)}; # truecase sentence start
    }
    elsif (defined($self->known->{$word})) {
      push @sentence, $word; # don't change known words
    }
    elsif (defined($self->best->{lc($word)})) {
      push @sentence, $self->best->{lc($word)}; # truecase otherwise unknown words
    }
    else {
      push @sentence, $word; # unknown, nothing to do
    }
    push @sentence, $otherfactors;

    if    ( defined($SENTENCE_END{ $word }))           { $sentence_start = 1; }
    elsif (!defined($DELAYED_SENTENCE_START{ $word })) { $sentence_start = 0; }
  }
  push @sentence, $$MARKUP[$#$MARKUP];

    $zone->set_sentence((join '', @sentence));
    return;
}

# store away xml markup
sub split_xml {
  my ($line) = @_;
  my (@WORD,@MARKUP);
  my $i = 0;
  $MARKUP[0] = "";
  while($line =~ /\S/) {
    # XML tag
    if ($line =~ /^\s*(<\S[^>]*>)(.*)$/) {
      my $potential_xml = $1;
      my $line_next = $2;
      # exception for factor that is an XML tag
      if ($line =~ /^\S/ && scalar(@WORD)>0 && $WORD[$i-1] =~ /\|$/) {
	$WORD[$i-1] .= $potential_xml;
	if ($line_next =~ /^(\|+)(.*)$/) {
	  $WORD[$i-1] .= $1;
	  $line_next = $2;
	}
      }
      else {
        $MARKUP[$i] .= $potential_xml." ";
      }
      $line = $line_next;
    }
    # non-XML text
    elsif ($line =~ /^\s*([^\s<>]+)(.*)$/) {
      $WORD[$i++] = $1;
      $MARKUP[$i] = "";
      $line = $2;
    }
    # '<' or '>' occurs in word, but it's not an XML tag
    elsif ($line =~ /^\s*(\S+)(.*)$/) {
      $WORD[$i++] = $1;
      $MARKUP[$i] = "";
      $line = $2;
      }
    else {
      log_fatal("ERROR: huh? $line\n");
    }
  }
  chop($MARKUP[$#MARKUP]);
  return (\@WORD,\@MARKUP);
}


1;

=head1 NAME 

Treex::Block::TruecaseMoses -- perl wrapper of Moses script truecase.perl

# $Id: train-recaser.perl 1326 2007-03-26 05:44:27Z bojar $

=head1 PARAMETERS

=over

=item model_dir

=item model

=item asr

ASR input has no case, make sure it is lowercase, and make sure known are cased eg. 'i' to be uppercased even if i is known

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Ondřej Bojar <bojar@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

This file is licensed under the GNU Lesser General Public License version 2.1
or, at your option, any later version.

