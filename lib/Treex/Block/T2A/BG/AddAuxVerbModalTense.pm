package Treex::Block::T2A::BG::AddAuxVerbModalTense;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddAuxVerbModalTense';

override '_build_gram2form' => sub {

    return {
        '' => {
            '' => {
                'decl'    => '',
                'poss'    => 'мога да',
                'vol'     => 'искам да',
                'deb'     => 'трябва да',
                'hrt'     => 'трябва да',
                'fac'     => '',
                'perm'    => 'може да',
            },
        },
        'ind' => {
            'sim' => {
                ''        => '',
                'decl'    => '',
                'poss'    => 'мога да',
                'vol'     => 'искам да',
                'deb'     => 'трябва да',
                'hrt'     => 'трябва да',
                'fac'     => '',
                'perm'    => 'може да',
            },
        },
    };

# TODO
#             'ant' => {
#                 ''        => '',
#                 'decl'    => '',
#                 'poss'    => 'could',
#                 'poss_ep' => 'can have',
#                 'vol'     => 'wanted to',
#                 'deb'     => 'had to',
#                 'deb_ep'  => 'must have',
#                 'hrt'     => 'had to',
#                 'fac'     => 'was able to',
#                 'perm'    => 'could',
#                 'perm_ep' => 'may have',
#             },
#             'post' => {
#                 ''     => 'will',
#                 'decl' => 'will',
#                 'poss' => 'will be able to',
#                 'vol'  => 'will want to',
#                 'deb'  => 'will have to',
#                 'hrt'  => 'will have to',
#                 'fac'  => 'will be able to',
#                 'perm' => 'will be able to',
#             },
#         },
#         'cdn' => {
#             'sim' => {
#                 ''        => 'would',
#                 'decl'    => 'would',
#                 'poss'    => 'would be able to',
#                 'poss_ep' => 'could',
#                 'vol'     => 'would want to',
#                 'deb'     => 'would have to',
#                 'deb_ep'  => 'must',
#                 'hrt'     => 'would have to',
#                 'fac'     => 'would be able to',
#                 'perm'    => 'would be able to',
#                 'perm_ep' => 'might',
#             },
#             'ant' => {
#                 ''        => 'would have',
#                 'decl'    => 'would have',
#                 'poss'    => 'would have been able to',
#                 'poss_ep' => 'could have',
#                 'vol'     => 'would have wanted to',
#                 'deb'     => 'would have had to',
#                 'deb_ep'  => 'must have',
#                 'hrt'     => 'would have had to',
#                 'fac'     => 'would have been able to',
#                 'perm'    => 'would have been able to',
#                 'perm_ep' => 'might have',
#             },
#             'post' => {
#                 ''     => 'would',
#                 'decl' => 'would',
#                 'poss' => 'would be able to',
#                 'vol'  => 'would want to',
#                 'deb'  => 'would have to',
#                 'hrt'  => 'would have to',
#                 'fac'  => 'would be able to',
#                 'perm' => 'would be able to',
#             },
#         },
#     };
};

# TODO inflect
# override '_postprocess' => sub {
#     my ( $self, $verbforms_str, $anodes ) = @_;
# };

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::BG::AddAuxVerbModalTense

=head1 DESCRIPTION

Add auxiliary expression for combined modality and tense.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
