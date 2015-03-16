package Treex::Tool::TranslationModel::Derivative::EN2CS::Suffixes;
use Treex::Core::Common;
use Class::Std;
use utf8;
use base qw(Treex::Tool::TranslationModel::Derivative::Common);

use Treex::Tool::Lexicon::Generation::CS;
my $analyzer = Treex::Tool::Lexicon::Generation::CS->new();

my %ENSUFFIX_TO_CSSUFFIX = (
    qw(ise)   => [qw(izovat)],
    qw(ize)   => [qw(izovat)],
    qw(ism)   => [qw(izmus)],
    qw(phy)   => [qw(fie)],
    qw(logy)  => [qw(logie)],
    qw(cal)   => [qw(cký)],
    qw(cally) => [qw(cky kálně)],
    qw(ic)    => [qw(ický ský)],
    qw(ist)   => [qw(ista istický)],
    qw(ian)   => [qw(iánský ský ian ovský)],
    qw(ish)   => [qw(ský ovský)],
);


{

sub get_translations {
    my ($self, $input_label) = @_;

    my @translations;

    foreach my $en_suffix ( keys %ENSUFFIX_TO_CSSUFFIX ) {
        if ( $input_label =~ /$en_suffix$/ ) {
            foreach my $cs_suffix ( @{ $ENSUFFIX_TO_CSSUFFIX{$en_suffix} } ) {
                my $cs_tlemma = $input_label;
                $cs_tlemma =~ s/$en_suffix$/$cs_suffix/;
                my @analyses = grep { $_->{tag} =~ /^[NADV]/ } $analyzer->analyze_form($cs_tlemma);
                if (@analyses) {
                    my $pos = substr( $analyses[0]->{tag}, 0, 1 );
                    push @translations, { prob   => 0.001,
                                          label  => "$cs_tlemma#$pos",
                                          source => 'Derivative::EN2CS::Suffixes',
                                        };
                }
            }
        }
    }

    return @translations;
}

}    


1;

__END__

=head1 NAME

TranslationModel::Derivative::EN2CS::Suffixes


=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2010 David Marecek
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
