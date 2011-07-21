package Treex::Tool::Lexicon::EN;
use Treex::Core::Common;
use autodie;
use utf8;

my @DICENDI_VERBS =
    qw(add admit affirm announce appear ask assure believe claim clarify
    comment conclude declare describe estimate explain explicate justify know mean note recognize
    reply rumble say seem specify state stress tell think utter write);
my %IS_DICENDI_VERB;
foreach my $lemma (@DICENDI_VERBS) {
    $IS_DICENDI_VERB{$lemma} = 1;
}

sub is_dicendi_verb {
    my ($t_lemma) = @_;
    log_fatal('uninitialized t_lemma in Treex::Tool::Lexicon::EN::is_dicendi_verb') if !defined $t_lemma;
    return $IS_DICENDI_VERB{$t_lemma};
}

my %NUMBER_FOR = (
    zero => 0, one => 1, two => 2, three => 3, four => 4, five => 5,
    six    => 6,  seven  => 7,  eight    => 8,  nine     => 9,  ten     => 10,
    eleven => 11, twelve => 12, thirteen => 13, fourteen => 14, fifteen => 15,
    sixteen  => 16,    seventeen => 17,        eighteen => 18,            nineteen => 19,
    twenty   => 20,    thirty    => 30,        fourty   => 40,            fifty    => 50,
    sixty    => 60,    seventy   => 70,        eighty   => 80,            ninety   => 90, hundred => 100,
    thousand => 1_000, million   => 1_000_000, billion  => 1_000_000_000, milliard => 1_000_000_000,
);

sub number_for {
    my ($word) = @_;
    return $word if $word =~ /^\d+$/;
    return $NUMBER_FOR{$word};
}

my %NUMBER_OF_MONTH = (
    January => 1, February => 2, March     => 3, April   => 4,  May      => 5,  June     => 6,
    July    => 7, August   => 8, September => 9, October => 10, November => 11, December => 12,
);

sub number_of_month {
    my ($lemma) = @_;
    return $NUMBER_OF_MONTH{$lemma};
}

my %personal_role;
my $persrole_filename = $ENV{TMT_ROOT} . "/treex/lib/Treex/Tool/Lexicon/english_personal_roles.txt";    # !!! detekci adresare udelat poradne
open my $P, "<:utf8", $persrole_filename;
while (<$P>) {
    chomp;
    $personal_role{$_} = 1;
}
close($P);

sub is_personal_role {
    my ($lemma) = @_;
    return $personal_role{$lemma};
}

sub truncate_lemma {
    return @_;
}

# Returns true if the given belongs to a modal verb.
sub is_modal_verb {
    my ($lemma) = @_;
    return $lemma =~ m/^(can|could|may|might|shall|should|must|ought|will)$/;
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::EN

=head1 SYNOPSIS

use Treex::Tool::Lexicon::EN;

print Treex::Tool::Lexicon::EN::number_for('seven'); # prints 7


=head1 DESCRIPTION

This module should include support for miscellaneous queries
involving English lexicon and morphology.  

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
