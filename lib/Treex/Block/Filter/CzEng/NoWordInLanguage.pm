package Treex::Block::Filter::CzEng::NoWordInLanguage;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::CzEng::Common';

has 'dictionary' => (
    isa => 'HashRef[HashRef[Str]]',
    is  => 'rw'
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en_forms = map { $_->get_attr('form') } $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs_forms = map { $_->get_attr('form') } $bundle->get_zone('cs')->get_atree->get_descendants;

    my @seen  = ();
    my @valid = ();

    # 0->single-letter words, 1->two-letter, 2->three-letter, 3->four+
    my $ok = 0;
    for my $lang (qw( cs en )) {
        for my $w ( eval "\@$lang" . "_forms" ) {
            my $class = length($w) - 1;
            $class = 3 if $class > 3;
            $seen[$class]++;
            $valid[$class]++ if $self->{dictionary}->{$lang}->{$w};
            $ok = 1 if $valid[3];
            $ok = 1 if $ok == 0 && $valid[2] && ( !defined $seen[3] || $seen[3] < 2 );
            $ok = 1 if $ok == 0 && $valid[1] && ( !defined $seen[2] || $seen[2] < 2 );
        }
    }
    if ( !$ok ) {
        $self->add_feature( $bundle, "no_word_in_language" );
    }
    return 1;
}

sub BUILD
{
    my $self = shift;

    # load dictionaries

    # for English
    # # just the English side of the old GIZA++ dictionary
    # my $dictf = "/export/projects/tectomt_shared/resource_data/translation_dictionaries/czeng.eaca.1-1.int.just-lcforms.dict.gz";
    my $dictf = "/net/projects/tectomt_shared/generated_data/extracted_from_BNC/freqlist";
    log_info "Loading dictionary for en: $dictf";
    my $dicth = my_open($dictf);
    my %dict;
    binmode( $dicth, ":encoding(iso-8859-1)" );
    while (<$dicth>) {
        chomp;
        my ( $word, $tag, $cnt ) = split /\t/;
        next if !defined $cnt;
        next if $cnt eq "##";    # title line
        next if $cnt < 2;        # require at least two occs
        foreach my $w ( split /\b/, $word ) {    # resplit words
            next if $w !~ /[[:alpha:]]/;
            $self->{dictionary}->{"en"}->{ lc($w) } = 1;    # lowercasing
        }
    }
    close $dicth;

    {                                                       # Czech dict
        my $dictf = "/net/projects/tectomt_shared/resource_data/czech_wordforms_from_syn.txt.gz";
        log_info "Loading dictionary for cs: $dictf";
        my $dicth = my_open($dictf);
        while (<$dicth>) {
            chomp;
            my ( $cnt, $word ) = split /\t/;
            next if $cnt < 2;                               # require at least two occs
            foreach my $w ( split /\b/, $word ) {           # resplit words
                next if $w !~ /[[:alpha:]]/;
                my $lc = lc($w);                            # lowercasing
                $self->{dictionary}->{"cs"}->{$lc} = 1;
            }
        }
        close $dicth;
    }

    return 1;
}

sub my_open {
    my $f = shift;
    if ( $f eq "-" ) {
        binmode( STDIN, ":utf8" );
        return *STDIN;
    }

    die "Not found: $f" if !-e $f;

    my $opn;
    my $hdl;
    my $ft = `file '$f'`;

    # file might not recognize some files!
    if ( $f =~ /\.gz$/ || $ft =~ /gzip compressed data/ ) {
        $opn = "zcat '$f' |";
    }
    elsif ( $f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/ ) {
        $opn = "bzcat '$f' |";
    }
    else {
        $opn = "$f";
    }
    open $hdl, $opn or die "Can't open '$opn': $!";
    binmode $hdl, ":utf8";
    return $hdl;
}

return 1;

=pod

Fire if there is no Czech (English) word on Czech (English) side.

=cut
