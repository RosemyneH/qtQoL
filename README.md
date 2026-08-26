<div align="center">
  <h1>qtQOL</h1>
  <p>Party quality-of-life tools built exclusively for the PeloriaWoW 3.3.5a private server.</p>
  <p><strong>PeloriaWoW only · World of Warcraft 3.3.5a · Addon version 1.0.0</strong></p>
</div>

<blockquote>
  <strong>Compatibility:</strong> qtQOL depends on PeloriaWoW's custom interface and server features.
  It is not intended for Blizzard clients, Classic, Retail, or other private servers.
</blockquote>

<h2>Features</h2>

<ul>
  <li>
    <strong>Party Elite Bounty board</strong> — view every party member's Elite bounty targets
    beside the Peloria bounty window.
  </li>
  <li>
    <strong>Party and instance views</strong> — organize targets by party member or raid instance.
  </li>
  <li>
    <strong>One-click queueing</strong> — queue for an available bounty target from the board.
  </li>
  <li>
    <strong>Party sharing</strong> — sync bounty progress with party members who also use qtQOL.
  </li>
  <li>
    <strong>Quick announcements</strong> — post your current Elite bounty targets to party chat.
  </li>
  <li>
    <strong>Transmog browsing improvements</strong> — reduce bulk item-cache queries and refresh
    missing icons while browsing Peloria's transmog interface.
  </li>
</ul>

<h2>Installation</h2>

<ol>
  <li>Download or clone this repository.</li>
  <li>
    Copy the inner <code>qtQOL</code> folder into
    <code>World of Warcraft/Interface/AddOns/</code>.
  </li>
  <li>
    Confirm the final path is
    <code>World of Warcraft/Interface/AddOns/qtQOL/qtQOL.toc</code>.
  </li>
  <li>Start the PeloriaWoW 3.3.5a client and enable <strong>qtQOL</strong> on the AddOns screen.</li>
</ol>

<p>If the addon does not appear, check that it is not nested inside an extra repository folder.</p>

<h2>Using the bounty board</h2>

<p>
  Open Peloria's bounty window. qtQOL adds a <strong>Party Elite Bounties</strong> panel beside it.
</p>

<table>
  <thead>
    <tr>
      <th>Control</th>
      <th>What it does</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Say Mine</strong></td>
      <td>Posts your loaded Elite bounty targets and completion status to party chat.</td>
    </tr>
    <tr>
      <td><strong>Sync Party</strong></td>
      <td>Requests fresh bounty information from party members running qtQOL.</td>
    </tr>
    <tr>
      <td><strong>Instances / Party</strong></td>
      <td>Switches between targets grouped by raid and targets grouped by party member.</td>
    </tr>
    <tr>
      <td><strong>Queue</strong></td>
      <td>Selects the target's queue and joins it using your current LFG role.</td>
    </tr>
  </tbody>
</table>

<p>
  Every party member must have qtQOL enabled for their bounty information to appear.
  The board refreshes automatically when party membership or bounty progress changes.
</p>

<h2>Troubleshooting</h2>

<ul>
  <li>
    <strong>No party data:</strong> make sure everyone has qtQOL enabled, then press
    <strong>Sync Party</strong>.
  </li>
  <li>
    <strong>Queue cancelled:</strong> select a tank, healer, or damage role in the LFG interface
    and try again.
  </li>
  <li>
    <strong>Addon is missing:</strong> verify the installation path and enable it from the
    character-selection AddOns menu.
  </li>
</ul>

<h2>License</h2>

<p>
  qtQOL is free software licensed under the
  <a href="LICENSE">GNU General Public License, version 2.0 only</a>.
</p>
