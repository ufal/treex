package Treex::Scen::Synthesis::PT;
use Moose;
use Treex::Core::Common;

has lxsuite_key => (
    is => 'ro',
    isa => 'Str',
    default => 'nlx.qtleap.13417612987549387402',
    documentation => 'Secret password to access Portuguese servers',
);

has lxsuite_host => (
    is => 'ro',
    isa => 'Str',
    default => '194.117.45.198',
);

has lxsuite_port => (
    is => 'ro',
    isa => 'Str',
    default => '10000',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'Util::SetGlobal lxsuite_host=' . $self->lxsuite_host . ' lxsuite_port=' . $self->lxsuite_port,
    'Util::SetGlobal lxsuite_key=' . $self->lxsuite_key,
    'T2A::CopyTtree',
    'T2A::PT::ImposeLemma',
    'T2A::PT::ImposeFormeme',
    'T2A::PT::MarkSubject',
    'T2A::PT::InitMorphcat',
    'T2A::PT::SecondPersonPoliteness',
    'T2A::PT::AddGender',
    'T2A::PT::AddAuxVerbCompoundPassive',
    'T2A::PT::AddConditional',
    'T2A::PT::FixPossessivePronouns',
    'T2A::PT::AddArticles',
    'T2A::PT::AddAuxVerbModalTense',
    'T2A::PT::AddVerbNegation',
    'T2A::PT::AddPrepos',
    'T2A::AddSubconjs',
    'T2A::AddCoordPunct',
    'T2A::PT::AddComparatives',
    'T2A::PT::MoveRhematizers',
    'T2A::ImposeSubjpredAgr',
    'T2A::ImposeAttrAgr',
    'T2A::PT::DropSubjPersProns',
    'T2A::DropPersPronSb',
    'T2A::ProjectClauseNumber',
    'T2A::AddParentheses',
    'T2A::AddSentFinalPunct',
    'T2A::PT::GenerateWordforms',
    'T2A::PT::GeneratePronouns',
    'T2A::PT::CliticExceptions',
    q|Util::Eval anode='$.set_tag(join " ", $.get_iset_values())'|,
    'T2A::DeleteSuperfluousAuxCP',
    'T2A::PT::PrepositionContraction',
    'T2A::CapitalizeSentStart',
    'A2W::PT::ConcatenateTokens',

    # this is the place for temporary regex-based hacks:
    'A2W::PT::DirtyTricks',
    ;
    return $scen;
}

1;

__END__
