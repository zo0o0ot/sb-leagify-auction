export type AuctionStatus = 'draft' | 'practice' | 'in_progress' | 'paused' | 'completed' | 'archived'

export type ParticipantRole = 'auction_master' | 'team_coach' | 'viewer'

export type BidType = 'nomination' | 'bid' | 'pass'

export interface Auction {
  id: number
  join_code: string
  name: string
  status: AuctionStatus
  created_by: number
  default_budget: number
  current_nominator_id: number | null
  current_school_id: number | null
  current_high_bid: number | null
  current_high_bidder_id: number | null  // references participants.id
  created_at: string
  started_at: string | null
  completed_at: string | null
}

export interface Team {
  id: number
  auction_id: number
  team_name: string
  budget: number
  remaining_budget: number
  nomination_order: number
  has_nominated_this_round: boolean
  is_active: boolean
  auto_pass_enabled: boolean
  participant_id?: number | null  // derived — not a DB column
}

export interface Participant {
  id: number
  auction_id: number
  display_name: string
  role: ParticipantRole
  team_id: number | null
  session_token: string | null
  is_connected: boolean
  is_ready: boolean
  has_practiced: boolean
  user_id: number | null
}

export interface School {
  id: number
  name: string
  logo_url: string | null
  logo_filename: string | null
}

export interface AuctionSchool {
  id: number
  auction_id: number
  school_id: number
  leagify_position: string
  conference: string | null
  projected_points: number
  suggested_value: number | null
  is_available: boolean
  school?: School
}

export interface DraftPick {
  id: number
  auction_id: number
  team_id: number
  auction_school_id: number
  roster_position_id: number
  winning_bid: number
  pick_order: number
  auction_school?: AuctionSchool
}

export interface RosterPosition {
  id: number
  auction_id: number
  position_name: string
  slots_per_team: number
  is_flex: boolean
  display_order: number
  color_code: string
}

export interface BidHistory {
  id: number
  auction_id: number
  auction_school_id: number
  participant_id: number
  team_id: number | null
  bid_type: BidType
  amount: number
  is_winning_bid: boolean
  is_practice: boolean
  on_behalf_of_team_id: number | null
  created_at: string
}

export interface Session {
  participantId: number
  auctionId: number
  teamId: number | null
  role: ParticipantRole
  displayName: string
  sessionToken: string
  supabaseUid: string
}
