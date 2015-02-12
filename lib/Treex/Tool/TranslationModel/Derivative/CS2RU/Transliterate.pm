package Treex::Tool::TranslationModel::Derivative::CS2RU::Transliterate;
use Treex::Core::Common;
use utf8;
use Class::Std;

use base qw(Treex::Tool::TranslationModel::Derivative::Common);

sub get_translations {
    my ( $self, $lemma, $features_array_rf ) = @_;
    
    # tvrdý znak ъЪ, měkký znak ьЬ,   
        
    # lowercase
    $lemma =~ s/_s[ei]$/ся/g; # reflexive verbs
    $lemma =~ s/pře/пере/g;
    $lemma =~ s/^roz/раз/g;
    $lemma =~ s/ý$/ый/g; # TODO  ой
    #TODO: ďa, ťo, ňu,... -> дя, тё, ню
    
    $lemma =~ s/jo/ё/g;
    $lemma =~ s/ch/х/g;
    $lemma =~ s/šč/щ/g;
    $lemma =~ s/ch/х/g;
    $lemma =~ s/j[uúů]/ю/g;
    $lemma =~ s/j[aá]/я/g;
    $lemma =~ tr{abvgděžzijklmnoprstufcčšyeáďéíóřťúůýh}
                {абвгдежзийклмнопрстуфцчшыэаdeиортууыг};

    # Uppercase
    $lemma =~ s/jo/Ё/gi;
    $lemma =~ s/ch/Х/gi;
    $lemma =~ s/šč/Щ/gi;
    $lemma =~ s/ch/х/gi;
    $lemma =~ s/j[uúů]/Ю/gi;
    $lemma =~ s/j[aá]/Я/gi;
    $lemma =~ tr{ABVGDĚŽZIJKLMNOPRSTUFCČŠYEÁĎÉÍÓŘŤÚŮÝH}
                {АБВГДЕЖЗИЙКЛМНОПРСТУФЦЧШЫЭАДЕИОРТУУЫГ};

    return { label => $lemma, source => 'Derivative::CS2RU::Transliterate', prob => 1 };
}

1;

__END__

=encoding utf8

=head1 NAME

TranslationModel::Derivative::CS2RU::Transliterate

=head1 DESCRIPTION

Backoff translation of Czech (latin) alphabet to Cyrillic.

=head1 COPYRIGHT

Copyright 2012 Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
