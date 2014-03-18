package Treex::Tool::DerivMorpho::Dictionary;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Treex::Tool::DerivMorpho::Lexeme;

use Treex::Core::Log;

use Scalar::Util qw(weaken);

use PerlIO::via::gzip;
use Storable;


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

    my $new_lexeme = Treex::Tool::DerivMorpho::Lexeme->new(@_);
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

    if ( $filename =~ /\.slex$/ ) { # derivational lexicon in perl storable format
        open( my $F, ">:via(gzip)", $filename ) or log_fatal $!;
        print $F Storable::nfreeze($self);
        close $F;
        return;
    }

    elsif ( $filename =~ /\.tsv$/ ) {
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
            print $F join "\t",($lexeme->{_lexeme_number}, $lexeme->lemma, $lexeme->mlemma || '', $lexeme->pos || '',
                                ($lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : ''),
                                ( $lexeme->deriv_type || '' ),
                                ( $lexeme->lexeme_creator || '' ),
                                ( $lexeme->derivation_creator || '' ),
                            );
            print $F "\n";
            $lexeme_number++;
        }

        close $F;
    }

    else {
        log_fatal("Unrecognized file ending: $filename\n");
    }

}

sub _number2id {

}

sub load {
    my ( $self, $filename, $argref ) = @_;

    if ( $filename =~ /\.slex$/ ) {

        open my $FILEHANDLE, "<:via(gzip)", $filename or log_fatal($!);
        my $serialized;
        # reading it this way is silly, but both slurping the file or
        #  using Storable::retrieve_fd lead to errors when used with via(gzip)
        while (<$FILEHANDLE>) {
            $serialized .= $_;
        }
        my $retrieved_dictionary = Storable::thaw($serialized) or log_fatal $!;

        # moving the content from the retrieved dictionary into the already existing instance
        # (risky)
        foreach my $key (keys %$retrieved_dictionary) {
            $self->{$key} = $retrieved_dictionary->{$key}
        }
        return $self;
    }

    elsif ( $filename =~ /\.tsv$/ ) {

        $self->_set_lexemes([]);
        $self->_set_lemma2lexemes({});
        $self->_set_mlemma2lexeme({});

        my %derived_number_to_source_number;

        open my $F,'<:utf8',$filename or die $!;
        my $linenumber;
        while (<$F>) {
            chomp;
            $linenumber++;
            last if $argref and $argref->{limit} and $argref->{limit} < $linenumber;
            my ($number, $lemma, $mlemma, $pos, $source_lexeme_number, $deriv_type, $lexeme_creator, $derivation_creator) = split /\t/;
            my $new_lexeme = $self->create_lexeme({lemma => $lemma,
                                                   mlemma => $mlemma,
                                                   pos => $pos,
                                               });
            if ($source_lexeme_number ne "") {
                if ($deriv_type) {
                    $new_lexeme->set_deriv_type($deriv_type);
                }
                if ($derivation_creator) {
                    $new_lexeme->set_derivation_creator($derivation_creator);
                }
                if ($lexeme_creator) {
                    $new_lexeme->set_lexeme_creator($lexeme_creator);
                }
                $derived_number_to_source_number{$number} = $source_lexeme_number;
            }
        }

        foreach my $derived_number (keys %derived_number_to_source_number) {
            my $derived_lexeme =  $self->_lexemes->[$derived_number];
            my $source_lexeme = $self->_lexemes->[$derived_number_to_source_number{$derived_number}];
            if ($source_lexeme) {
                $derived_lexeme->set_source_lexeme($source_lexeme);
            }
            else {
                log_warn("Non-existent numerical reference to source lexeme: $derived_number_to_source_number{$derived_number}");
            }
        }

        return $self;
    }

    else {
        log_fatal("Unrecognized file ending: $filename\n");
    }


}

sub add_derivation {
    my ( $self, $arg_ref ) = @_;
    my ( $source_lexeme, $derived_lexeme, $deriv_type, $derivation_creator ) =
        map { $arg_ref->{$_} } qw(source_lexeme derived_lexeme deriv_type derivation_creator);

    log_fatal("Undefined source lexeme") if not defined $source_lexeme;
    log_fatal("Undefined derived lexeme") if not defined $derived_lexeme;

    log_fatal("Source and derived lexemes must not be identical") if $source_lexeme eq $derived_lexeme;

    my @derivation_path = ($derived_lexeme, $source_lexeme);
    my $lexeme = $source_lexeme->source_lexeme;
    while ($lexeme) {
        push @derivation_path, $lexeme;
        if ($lexeme eq $derived_lexeme) {
            log_info("The new derivation would lead to a loop: "
                 . join (" -> ", reverse map {$_->lemma} @derivation_path)."   No derivation added.");
            return;
        }
        $lexeme = $lexeme->source_lexeme;
    }

    $derived_lexeme->set_source_lexeme($source_lexeme);
    $derived_lexeme->set_deriv_type($deriv_type);
    $derived_lexeme->set_derivation_creator($derivation_creator) if $derivation_creator;

    return $source_lexeme;
}

sub print_statistics {
    my ($self) = @_;

    my %pos_cnt;
    my %pos2pos_cnt;
    my $relations_cnt = 0;
    my %derived_lexemes_cnt;

    foreach my $lexeme ($self->get_lexemes) {
        $pos_cnt{$lexeme->pos}++;
        if ($lexeme->source_lexeme) {
            $relations_cnt++;
            $pos2pos_cnt{$lexeme->source_lexeme->pos."2".$lexeme->pos}++
        }

        $derived_lexemes_cnt{scalar($lexeme->get_derived_lexemes)}++;
    }

    print "LEXEMES\n";
    print "  Number of lexemes: ".scalar(@{$self->_lexemes})."\n";
    print "  Number of lexemes by part of speech:\n";
    foreach my $pos (sort {$pos_cnt{$b}<=>$pos_cnt{$a}} keys %pos_cnt) {
        print "    $pos $pos_cnt{$pos}\n";
    }

    print "\nDERIVATIVE RELATIONS BETWEEN LEXEMES\n";
    print "  Total number of derivative relations: $relations_cnt\n";
    print "  Types of derivative relations (POS-to-POS):\n";
    foreach my $pos2pos (sort {$pos2pos_cnt{$b}<=>$pos2pos_cnt{$a}} keys %pos2pos_cnt) {
        print "    $pos2pos $pos2pos_cnt{$pos2pos}\n";
    }

    print "  Number of lexemes derived from a lexeme:\n";
    foreach my $derived (sort {$derived_lexemes_cnt{$b}<=>$derived_lexemes_cnt{$a}} keys %derived_lexemes_cnt) {
        print "    $derived $derived_lexemes_cnt{$derived}\n";
    }

    print "\nDERIVATIONAL CLUSTERS\n";

    my %signature_cnt;
    my %touched;
    my $i;

    foreach my $lexeme ($self->get_lexemes) {
        if (not $touched{$lexeme}) {
            my $root = $lexeme->get_root_lexeme;
            my $signature = $self->_get_subtree_pos_signature($root,\%touched);
            $signature_cnt{$signature}++;
        }
    }

    print "Types of derivational clusters:\n";
    my @signatures = sort {$signature_cnt{$b}<=>$signature_cnt{$a}} keys %signature_cnt;
    foreach my $signature (@signatures) {
        print "    $signature_cnt{$signature} $signature\n";
    }

}

sub _get_subtree_pos_signature {
    my ($self, $lexeme, $touched_rf) = @_;
    $touched_rf->{$lexeme} = 1;

    my $signature = $lexeme->pos;

    my @derived_lexemes = $lexeme->get_derived_lexemes;
    if (grep {not $touched_rf->{$_}} @derived_lexemes) { # prevent cycles
        my $child_signatures = join ',', sort map {$self->_get_subtree_pos_signature($_,$touched_rf)} @derived_lexemes;
        $signature .="->($child_signatures)"
    }
    return $signature;
}

1;
