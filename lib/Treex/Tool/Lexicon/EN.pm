package Treex::Tool::Lexicon::EN;
use Treex::Core::Common;
use autodie;
use utf8;

my @DICENDI_VERBS =
    qw(accuse acknowledge add admit affirm agree allege announce answer
    anticipate argue appear ask assert assure beg believe bet boast brag
    burst_out certify claim clarify comment conclude confess confide contend
    convey cry declare deny describe disclose doubt elaborate enlarge estimate
    exclaim explain explicate falter fear feel forecast foretell guarantee hint
    hope imagine insist justify know maintain mean mention mumble murmur mutter
    note object observe order phone pray predict proclaim promise pronounce
    prophesy protest purr realize recall recognize regret reject remark repeat
    reply report retort rumble say seem shout snap sneer sob specify state
    stress submit suggest suppose swear tell testify think urge utter vow warn
    whisper wonder write yell indicate signal);
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

    # Abbreviations (June and July are abbreviated only rarely)
    'Jan.' => 1, 'Feb.' => 2, 'Mar.'  => 3, 'Apr.' => 4,  'Jun.' => 6,  'Jul.' => 7,
    'Aug.' => 8, 'Sep.' => 9, 'Sept.' => 9, 'Oct.' => 10, 'Nov.' => 11, 'Dec.' => 12,
);

sub number_of_month {
    my ($lemma) = @_;
    return $NUMBER_OF_MONTH{$lemma};
}

my %NUMBER_OF_DAY = (
    monday => 1, tuesday => 2, wednesday => 3, thursday => 4,
    friday => 5, saturday => 6, sunday => 7,
);

sub number_of_day {
    my ($lemma) = @_;
    return $NUMBER_OF_DAY{ lc $lemma };
}

sub truncate_lemma {
    return @_;
}

# Returns true if the given lemma belongs to a modal verb.
sub is_modal_verb {
    my ($lemma) = @_;
    return $lemma =~ m/^(can|could|may|might|shall|should|must|ought|will)$/;
}

# a list of English verbs that take a bare infinitive (without "to") as an object
Readonly my $BARE_INFIN_VERBS => "hear|see|watch|feel|sense|make|bid|let|have|help|dare";

sub takes_bare_infin {
    my ($lemma) = @_;
    return $lemma =~ m/^($BARE_INFIN_VERBS)$/;
}

# verbs with object control type, copied from page 286
# in Pollard & Sag's Head-driven phrase structure grammar
my @OBJECT_CONTROL_VERBS =
    qw(order persuade bid charge command direct enjoin
    instruct advise authorize mandate convince impel induce influence inspire
    motivate move pressure prompt sway stir compel press propel push spur
    encourage exhort goad incite urge bring lead signal ask empower appeal
    dare defy beg prevent forbid allow permit enable cause force consider);
my %IS_OBJECT_CONTROL_VERB = map { $_ => 1 } @OBJECT_CONTROL_VERBS;

sub is_object_control_verb {
    my ($t_lemma) = @_;
    log_fatal('uninitialized t_lemma in Treex::Tool::Lexicon::EN::is_object_control_verb') if !defined $t_lemma;
    return $IS_OBJECT_CONTROL_VERB{$t_lemma};
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

=head1 FUNCTIONS

=head2 $bool = is_object_control_verb($lemma)

Verbs with object control type, copied from page 286
in Pollard & Sag's Head-driven phrase structure grammar.

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
