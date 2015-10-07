package Treex::Tool::Gazetteer::RuleBasedScorer;

use Moose;

my $weights = {
    full_str_eq => [0, 2],
    full_str_non_alpha => [0, -100],
    first_starts_capital => [-10, 10],
    entity_starts_capital => [-50, 10],
    all_start_capital => [-1, 1],
    no_first => [-50, 1],
    last_menu => [0, -50],
};

sub score {
    my ($feats) = @_;

    my %feat_hash = ();
    my $score = 0;

    foreach my $pair (@$feats) {
        my ($key, $value) = @$pair;
        $feat_hash{$key} = $value;
        next if (!defined $weights->{$key});
        
        $value = $value >= 1 ? 1 : 0;
        $score += $weights->{$key}->[$value];
    }
    my $anode_count = $feat_hash{anode_count} // 1;

    return $score * $anode_count;
}

1;
