package Treex::Block::A2W::CS::ApplySubstitutions;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

#my $DEFAULT_TSV = 'data/models/translation/substitutions/cs_wmt2007-2010.tsv';
my $DEFAULT_TSV = 'data/models/translation/substitutions/cs_wmt2007-2010_without_dev2009.tsv';

sub get_required_share_files { return $DEFAULT_TSV; }

has file => (
    is      => 'rw',
    isa     => 'Str',
    default => "$ENV{TMT_ROOT}/share/$DEFAULT_TSV",    #TODO: change to Treex::Core::Config
);

my %change;
use autodie;

sub BUILD {
    my ($self) = @_;
    open my $F, '<:utf8', $self->file;
    my %h;
    while (<$F>) {
        my ( $from, $to ) = split /\t/, $_, 3;
        $to =~ s/<S> ?//;
        next if $change{$from};
        $change{$from} = $to;
    }
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my @tokens = split / /, $zone->sentence;
    my $last_token = '<S>';
    foreach my $i ( 0 .. $#tokens ) {
        my $token  = $tokens[$i];
        my $bigram = "$last_token $token";
        if ( defined $change{$bigram} ) {
            $tokens[$i] = $change{$bigram};
            $tokens[ $i - 1 ] = '' if $i;
            $last_token = '<NO>';
        }
        elsif ( defined $change{$token} ) {
            $tokens[$i] = $change{$token};
            $last_token = '<NO>';
        }
        else {
            $last_token = $token;
        }
    }
    $zone->set_sentence( join ' ', @tokens );
    return;
}

1;

=over

=item Treex::Block::A2W::CS::ApplySubstitutions



=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or newer. See $TMT_ROOT/README.
