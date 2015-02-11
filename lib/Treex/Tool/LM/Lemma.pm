package Treex::Tool::LM::Lemma;
use Treex::Core::Common;
use utf8;
use autodie;
use Readonly;
use Storable;

# Readonly my $LM_DIR       => $ENV{TMT_ROOT} . '/training/language_model/'; # '/share/data/models/language/cs/';
# Readonly my $DEFAULT_FILE => $LM_DIR . 'lemma_id.pls.gz';

# Id=0 is unused, so it is safe to write "if ($id)" instead of "if (defined $id)".
my @IDs = (undef);
my %ID_OF;

# This MUST be called before the usage of lemma IDs; otherwise nothing will work.
sub init {
    
    my ($lemma_file) = @_;

    if ( -f $lemma_file ) {
        _load_from_plsgz($lemma_file);
    }
    else {
        log_fatal("File '$lemma_file' not found. No lemma ids loaded.");
    }

}

#--- subroutines

sub _load_from_plsgz {
    my ($filename) = @_;
    log_info("Loading lemma ids from '$filename'");
    open my $PLSGZ, '<:gzip', $filename;
    my $model = Storable::fd_retrieve($PLSGZ);
    log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model );
    close $PLSGZ;
    @IDs   = @{ $model->[0] };
    %ID_OF = %{ $model->[1] };
}

sub id_of_lemma_and_pos {
    my ( $lemma, $pos ) = @_;
    return $ID_OF{"$lemma $pos"};
}

sub get_indexed {
    my ( $lemma, $pos ) = @_;
    my $id = $ID_OF{"$lemma $pos"};
    return undef if !$id;
    return bless \$id;
}

sub lemma_and_pos_of_id { $IDs[ $_[0] ] ? @{ $IDs[ $_[0] ] } : () }

#--- constructor and instance methods
sub new {
    my ( $class, $lemma, $pos ) = @_;
    if ( !defined $pos ) {
        ( $lemma, $pos ) = split / /, $lemma;
        $pos = '' if !defined $pos;
    }
    $lemma = lc $lemma;
    $lemma =~ s/\d+/<digit>/g;
    $lemma =~ s/ /&#32;/g;
    my $lemma_pos = "$lemma $pos";
    my $id        = $ID_OF{$lemma_pos};
    if ( !$id ) {
        $id = @IDs;
        push @IDs, [ $lemma, $pos ];
        $ID_OF{$lemma_pos} = $id;
    }
    return bless \$id, $class;
}

sub get_id    { ${ $_[0] }; }
sub get_lemma { $IDs[ ${ $_[0] } ][0]; }
sub get_pos   { $IDs[ ${ $_[0] } ][1]; }

#sub get_pos_id{ $ID_OF{' '. shift->get_pos()}; }
sub to_string { my $s = shift; $IDs[$$s][0] . ' ' . $IDs[$$s][1]; }

use overload (
    q{""}    => 'to_string',
    q{0+}    => 'get_id',
    fallback => 1,
);

1;

#TODO: verzování idéček
# Jak předejít tomu, aby se nějaký jazykový model natrénoval s jednou verzí idéček,
# pak se změnil soubor lemma_id.pls.gz (jiné mapování) a tím se to celé rozsypalo?
# Co ukládat do každého modelu využívajícího idéčka také hash souboru lemma_id?

__END__

#Bohužel Perl svádí k zrůdnostem jako je tato třída. I podlehl jsem.

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
