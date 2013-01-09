package Treex::Tool::Lexicon::DerivDict::Dictionary;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Treex::Tool::Lexicon::DerivDict::Lexeme;

use Treex::Core::Log;

use Scalar::Util qw(weaken);

has '_lexemes' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {[]},
    documentation => 'all lexemes loaded in the dictionary',
);

has '_lemma2lexemes' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
    documentation => 'an index that maps lemmas to lexeme instances',
);

has '_mlemma2lexeme' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
    documentation => 'an index that maps lemmas to lexeme instances',
);

sub get_lexemes {
    my $self = shift @_;
    return @{$self->_lexemes};
}

sub create_lexeme {
    my $self = shift @_;

    my $new_lexeme = Treex::Tool::Lexicon::DerivDict::Lexeme->new(@_);
    $new_lexeme->_set_dictionary($self);
    weaken($new_lexeme->{_dictionary}); # to avoid memory leaks due to ref. cycles

    push @{$self->_lexemes}, $new_lexeme;
    if ( $self->_lemma2lexemes->{$new_lexeme->lemma} ) {
        push @{$self->_lemma2lexemes->{$new_lexeme->lemma}}, $new_lexeme;
    }
    else {
        $self->_lemma2lexemes->{$new_lexeme->lemma} = [ $new_lexeme ];
    }
    return $new_lexeme;
}

sub get_lexemes_by_lemma {
    my ( $self, $lemma ) = @_;
    return @{$self->_lemma2lexemes->{$lemma} || []};
}

sub save {
    my ( $self, $filename ) = @_;
    $self->_set_lexemes( [ sort {$a->lemma cmp $b->lemma} $self->get_lexemes ] );

    my $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        $lexeme->{_lexeme_number} = $lexeme_number;
        $lexeme_number++;
    }

    open my $F, '>:utf8', $filename or die $!;

    $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        my $source_lexeme_number = $lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : '';
        print $F join "\t",($lexeme->{_lexeme_number}, $lexeme->lemma, $lexeme->mlemma, $lexeme->pos,
                         ($lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : ''),
                         $lexeme->deriv_type || '',
                     );
        print $F "\n";
        $lexeme_number++;
    }

    close $F;
}

sub _number2id {

}

sub load {
    my ( $self, $filename ) = @_;

    $self->_set_lexemes([]);
    $self->_set_lemma2lexemes({});
    $self->_set_mlemma2lexeme({});

    my %derived_number_to_source_number;

    open my $F,'<:utf8',$filename or die $!;
    while (<$F>) {
        chomp;
        my ($number, $lemma, $mlemma, $pos, $source_lexeme_number, $deriv_type) = split;
        my $new_lexeme = $self->create_lexeme({lemma => $lemma, mlemma=>$mlemma, pos=>$pos});
        if ($source_lexeme_number) {
            if ($deriv_type) {
                $new_lexeme->set_deriv_type($deriv_type);
            }
            $derived_number_to_source_number{$number} = $source_lexeme_number;
        }
    }

    foreach my $derived_number (keys %derived_number_to_source_number) {
        my $source_lexeme =  $self->_lexemes->[$derived_number];
        my $derived_lexeme = $self->_lexemes->[$derived_number_to_source_number{$derived_number}];
        $derived_lexeme->set_source_lexeme($source_lexeme);
    }

    return $self;
}

sub add_derivation {
    my ( $self, $arg_ref ) = @_;
    my ( $source_lexeme, $derived_lexeme, $deriv_type ) =
        map { $arg_ref->{$_} } qw(source_lexeme derived_lexeme deriv_type);

    log_fatal("Undefined source lexeme") if not defined $source_lexeme;
    log_fatal("Undefined derived lexeme") if not defined $derived_lexeme;
    $derived_lexeme->set_source_lexeme($source_lexeme);
    $derived_lexeme->set_deriv_type($deriv_type);
}

sub print_statistics {
    my ($self) = @_;

    my %pos_cnt;
    my %pos2pos_cnt;
    my $relations_cnt;
    my %derived_lexemes_cnt;

    foreach my $lexeme ($self->get_lexemes) {
        $pos_cnt{$lexeme->pos}++;
        if ($lexeme->source_lexeme) {
            $relations_cnt++;
            $pos2pos_cnt{$lexeme->source_lexeme->pos."2".$lexeme->pos}++
        }

        $derived_lexemes_cnt{scalar($lexeme->get_derived_lexemes)}++;
    }

    print "Number of lexemes: ".scalar(@{$self->_lexemes})."\n";
    print "Number of lexemes by part of speech:\n";
    foreach my $pos (sort {$pos_cnt{$b}<=>$pos_cnt{$a}} keys %pos_cnt) {
        print "    $pos $pos_cnt{$pos}\n";
    }

    print"Number of derivative relations:\n";
    print "Number of relations by POS-to-POS:\n";
    foreach my $pos2pos (sort {$pos2pos_cnt{$b}<=>$pos2pos_cnt{$a}} keys %pos2pos_cnt) {
        print "    $pos2pos $pos2pos_cnt{$pos2pos}\n";
    }

    print "Number of lexemes derived from a lexeme:\n";
    foreach my $derived (sort {$derived_lexemes_cnt{$b}<=>$derived_lexemes_cnt{$a}} keys %derived_lexemes_cnt) {
        print "    $derived $derived_lexemes_cnt{$derived}\n";
    }

}



1;
